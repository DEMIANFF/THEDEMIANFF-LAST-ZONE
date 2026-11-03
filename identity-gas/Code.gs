'use strict';

const PROJECT_ID = 'thedemianff-last-zone';
const IDENTITY_LOOKUP_URL = 'https://identitytoolkit.googleapis.com/v1/accounts:lookup';
const MAX_PLAYER_ID = 99999;
const SHEET_ID_PROPERTY = 'THEDEMIANFF_PLAYER_REGISTRY_SHEET_ID';
const COUNTER_PROPERTY = 'THEDEMIANFF_PLAYER_ID_COUNTER';
const API_KEY_PROPERTY = 'FIREBASE_WEB_API_KEY';
const EXPECTED_HEADERS = ['firebaseUid', 'playerNumber', 'createdAt'];

/** Run once from the Apps Script editor. Creates a private registry spreadsheet. */
function setupRegistry() {
  const properties = PropertiesService.getScriptProperties();
  const sheetId = properties.getProperty(SHEET_ID_PROPERTY);
  const counter = properties.getProperty(COUNTER_PROPERTY);
  if (sheetId || counter !== null) {
    if (!sheetId || counter === null) {
      throw new Error('Configuración parcial detectada. No se modificó el registro; requiere revisión manual.');
    }
    const existing = SpreadsheetApp.openById(sheetId);
    validateSheetHeaders_(existing.getSheetByName('players'));
    return existing.getUrl();
  }

  const spreadsheet = SpreadsheetApp.create('THEDEMIANFF — Registro privado de jugadores');
  const sheet = spreadsheet.getSheets()[0];
  sheet.setName('players');
  sheet.getRange(1, 1, 1, EXPECTED_HEADERS.length).setValues([EXPECTED_HEADERS]);
  sheet.setFrozenRows(1);
  SpreadsheetApp.flush();
  properties.setProperties({
    [SHEET_ID_PROPERTY]: spreadsheet.getId(),
    [COUNTER_PROPERTY]: '0',
  });
  return spreadsheet.getUrl();
}

/** Public health endpoint. It reveals no spreadsheet ID, API key, or player data. */
function doGet() {
  const properties = PropertiesService.getScriptProperties();
  const configured = Boolean(
    properties.getProperty(API_KEY_PROPERTY) &&
    properties.getProperty(SHEET_ID_PROPERTY) &&
    properties.getProperty(COUNTER_PROPERTY) !== null
  );
  return jsonOutput_({
    service: 'THEDEMIANFF player identity',
    projectId: PROJECT_ID,
    status: configured ? 'ready' : 'setup_required',
    maxPlayerId: MAX_PLAYER_ID,
  });
}

/** Receives only a Firebase ID token. The UID and player number are server-derived. */
function doPost(event) {
  try {
    if (!event || !event.postData || typeof event.postData.contents !== 'string' ||
        event.postData.contents.length < 20 || event.postData.contents.length > 12000) {
      throw serviceError_('INVALID_ARGUMENT');
    }
    const request = JSON.parse(event.postData.contents);
    if (!request || Array.isArray(request) || typeof request !== 'object' ||
        Object.keys(request).length !== 1 || typeof request.idToken !== 'string' ||
        request.idToken.length < 100 || request.idToken.length > 10000) {
      throw serviceError_('INVALID_ARGUMENT');
    }
    const uid = verifyFirebaseGoogleUser_(request.idToken);
    const number = assignPlayerNumber_(uid);
    return jsonOutput_({ ok: true, number: number });
  } catch (error) {
    const code = error && error.serviceCode ? error.serviceCode : 'INTERNAL';
    const safeMessages = {
      INVALID_ARGUMENT: 'Solicitud inválida.',
      UNAUTHENTICATED: 'La sesión de Google no es válida. Inicia sesión otra vez.',
      GOOGLE_REQUIRED: 'Conecta una cuenta Google para recibir un ID permanente.',
      NOT_CONFIGURED: 'El servicio de identidad todavía no está configurado por el administrador.',
      REGISTRY_CORRUPT: 'El registro o contador necesita una auditoría; no se asignó ningún ID.',
      RESOURCE_EXHAUSTED: 'Se agotó el rango de ID de cinco cifras.',
      BUSY: 'El registro está ocupado. Inténtalo de nuevo.',
      INTERNAL: 'No se pudo completar la asignación. No se confirmó ningún ID.',
    };
    return jsonOutput_({ ok: false, code: code, message: safeMessages[code] || safeMessages.INTERNAL });
  }
}

/** Verify the Firebase ID token against this project's Identity Toolkit API. */
function verifyFirebaseGoogleUser_(idToken) {
  const apiKey = PropertiesService.getScriptProperties().getProperty(API_KEY_PROPERTY);
  if (!apiKey || apiKey.length < 20) throw serviceError_('NOT_CONFIGURED');

  const response = UrlFetchApp.fetch(IDENTITY_LOOKUP_URL + '?key=' + encodeURIComponent(apiKey), {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ idToken: idToken }),
    muteHttpExceptions: true,
  });
  if (response.getResponseCode() !== 200) throw serviceError_('UNAUTHENTICATED');

  const body = JSON.parse(response.getContentText());
  const users = body && Array.isArray(body.users) ? body.users : [];
  if (users.length !== 1 || typeof users[0].localId !== 'string' ||
      !users[0].localId || users[0].disabled === true) {
    throw serviceError_('UNAUTHENTICATED');
  }
  const user = users[0];
  const providers = Array.isArray(user.providerUserInfo) ? user.providerUserInfo : [];
  const hasGoogleProvider = providers.some(provider => provider && provider.providerId === 'google.com');
  if (!hasGoogleProvider || user.emailVerified !== true) throw serviceError_('GOOGLE_REQUIRED');
  return user.localId;
}

/** Lock lookup + append + counter update. Inconsistent state is always rejected. */
function assignPlayerNumber_(uid) {
  const lock = LockService.getScriptLock();
  try {
    lock.waitLock(20000);
  } catch (error) {
    throw serviceError_('BUSY');
  }

  try {
    const properties = PropertiesService.getScriptProperties();
    const sheetId = properties.getProperty(SHEET_ID_PROPERTY);
    const counterRaw = properties.getProperty(COUNTER_PROPERTY);
    if (!sheetId || counterRaw === null) throw serviceError_('NOT_CONFIGURED');

    const counter = Number(counterRaw);
    if (!Number.isSafeInteger(counter) || counter < 0 || counter > MAX_PLAYER_ID) {
      throw serviceError_('REGISTRY_CORRUPT');
    }

    const spreadsheet = SpreadsheetApp.openById(sheetId);
    const sheet = spreadsheet.getSheetByName('players');
    validateSheetHeaders_(sheet);
    const lastRow = sheet.getLastRow();
    if (lastRow !== counter + 1) throw serviceError_('REGISTRY_CORRUPT');

    if (counter > 0) {
      const matches = sheet.getRange(2, 1, counter, 1)
        .createTextFinder(uid)
        .matchEntireCell(true)
        .findAll();
      if (matches.length > 1) throw serviceError_('REGISTRY_CORRUPT');
      if (matches.length === 1) {
        const row = matches[0].getRow();
        const existingNumber = Number(sheet.getRange(row, 2).getValue());
        if (!Number.isSafeInteger(existingNumber) || existingNumber < 1 ||
            existingNumber > counter || row !== existingNumber + 1) {
          throw serviceError_('REGISTRY_CORRUPT');
        }
        return existingNumber;
      }
    }

    if (counter >= MAX_PLAYER_ID) throw serviceError_('RESOURCE_EXHAUSTED');
    const nextNumber = counter + 1;
    sheet.getRange(lastRow + 1, 1, 1, 3).setValues([[uid, nextNumber, new Date()]]);
    SpreadsheetApp.flush();
    properties.setProperty(COUNTER_PROPERTY, String(nextNumber));
    return nextNumber;
  } finally {
    lock.releaseLock();
  }
}

function validateSheetHeaders_(sheet) {
  if (!sheet) throw serviceError_('REGISTRY_CORRUPT');
  const actual = sheet.getRange(1, 1, 1, EXPECTED_HEADERS.length).getValues()[0];
  for (let i = 0; i < EXPECTED_HEADERS.length; i += 1) {
    if (actual[i] !== EXPECTED_HEADERS[i]) throw serviceError_('REGISTRY_CORRUPT');
  }
}

function serviceError_(code) {
  const error = new Error(code);
  error.serviceCode = code;
  return error;
}

function jsonOutput_(value) {
  return ContentService.createTextOutput(JSON.stringify(value))
    .setMimeType(ContentService.MimeType.JSON);
}
