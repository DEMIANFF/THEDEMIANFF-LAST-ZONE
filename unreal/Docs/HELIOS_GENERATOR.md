# Aurora — Complejo Helios procedural blockout

The `AAuroraHeliosGenerator` actor is an editor-callable blockout generator using instanced cube meshes for ground tiles, walls, pillars and an antenna. It does not include final 3D architecture, textures, lighting, interiors, or a playable level.

## Once Unreal Editor is available
1. Compile the C++ project.
2. Create an empty map and add a PlayerStart.
3. Drag `AuroraHeliosGenerator` into the level.
4. In Details click `Generate Helios` (Call In Editor).
5. Verify the geometry, door openings, collision, dimensions, and performance.
6. Replace placeholder meshes with licensed architectural modules and PBR materials.
7. Save as `Content/Maps/Aurora_Helios.umap`.

**Important:** The source has not been compiled with Unreal. The generator runs only after the project is opened and compiled on a compatible host. The generated instances are actor component data, not a committed `.umap` file.
