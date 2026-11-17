# Sa7bi AI HERO 3D asset

The application uses one 3D Sa7bi character only: `sa7bi_hero.glb`.

## Model path

`assets/3d/sa7bi_hero.glb`

## Existing body animations

- `Hero_Idle`
- `Hero_Welcome`
- `Hero_Power`

The model is rendered locally with `model_viewer_plus`. The app icon artwork is embedded in the GLB as a PNG texture and is intended to remain visible as the chest emblem/energy core. Keep the current original app logo and its colors; do not replace it with a letter, generic shield, or a different mark.

## Face-rig status

The existing asset diagnostic test parses the GLB and checks for its embedded PNG texture and body animations. Its latest recorded diagnostic found no facial morph targets, no facial bones in the skin joint list, and no facial animation clips. Face likeness to the founder and live lip-sync are therefore not implemented by the current GLB yet.

The next model revision must update this same HERO asset, not add another character. Preserve the current superhero body, chest logo, and the three body animation names. Add a face modeled from the founder reference image and a proper facial rig/morph targets for blinking, brows, smile, jaw movement, and mouth visemes.

## Platform note

Keep the existing Android local model-viewer networking configuration. Do not enable unrestricted remote cleartext traffic to load this bundled local asset.
