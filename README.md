<h1>Godot Grand Strategy Map</h1>

![Visual description of concept](/Assets/Demo.jpg "Image Title")

This is a project for the <a href="https://godotengine.org/">Godot game engine</a>.

<h2>General Concept</h2>

![Visual description of concept](/Assets/ConceptImage.jpg "Image Title")

The program starts by reading the 'province image', located at /Assets/states.bmp, and turing it into a <a href="https://docs.godotengine.org/en/latest/classes/class_packedbytearray.html">PackedByteArray</a>, this is a format that the engine can pass to the compute shader. As well, a 'look up' texture is created. This is essentially converting a 1D index value to a 2D index value. Using the ID provided in /Assets/states_cache.json. Each id needs to be a unique unsigned integer. i.e. the top image in step 2 in the image above. 

<h3>Compute Shader</h3>

The compute shader takes in the data and converts it to an image where each pixel is the uv coordinate for the colour look up image. i.e. bottom image in step 2 in the image above.

<h3>GdShader</h3>

The results of the compute shader are used as uniforms in a godot shader. Which results in step 3 in the above image. 

<h2>How to use</h2>


You can open the project in the Godot editor and just press play. Hover over the different states of Denmark and Germany and you should see a unique id in the label below.  

<b>Note that a limitation right now is that the image given can only be 128x64. You can easily change that by editing the project. See comment on line 137 of Root.gd</b>


<h2>References</h2>

A great resource used was <a href="https://www.intel.com/content/www/us/en/developer/articles/technical/optimized-gradient-border-rendering-in-imperator-rome.html">this post</a> on Intel.com by Bartosz Boczula, Daniel Eriksson
