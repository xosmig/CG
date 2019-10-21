## Assignment №5: SH diffuse shader

1. Select a HDR cubemap (for example, from [this site](http://noemotionhdrs.net/hdrday.html))
2. Import it into Unity. Select `Default / Cube` as texture type with `Default` mapping type 
3. Implement Monte-Carlo projection of that map into SH (`CubemapToSphericalHarmonic.compute::67`)
4. Get the results in `Scenes/6_SH` almost identical to those in `Scenes/5_Cubemap`
4. Send me a screenshot of your results at mischapanin@gmail.com along with your code.
5. The e-mail should have the following topic: __HSE.CG.<your_name>.<your_last_name>.HW5__

**Bonus points:** 
You can get an extra 10% bonus if you add a reflection based on a prefiltered cubemap.
You can get an extra 10% bonus if you support anisotropic reflections.

**Note:**
This *is* the solution, used in real games. Keep it fast. 
I encurage you finding a free PBR model on the internet and apply your shader to it.
