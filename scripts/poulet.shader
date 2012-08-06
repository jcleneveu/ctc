models/ctc/poulet
{
	nopicmip
	cull front

	{
		map models/ctc/poulet.tga
	}
	
	if textureCubeMap //for 3d cards supporting cubemaps
	{
		shadecubemap env/cell
		blendFunc filter
	}
	endif

	if ! textureCubeMap //for 3d cards not supporting cubemaps
	{
		map gfx/colors/celshade.tga
		blendfunc filter
		tcGen environment
	}
	endif
}

models/ctc/pouletmain
{
	nopicmip
	cull front

	{
		map models/ctc/pouletmain.tga
	}
	
	if textureCubeMap //for 3d cards supporting cubemaps
	{
		shadecubemap env/cell
		blendFunc filter
	}
	endif

	if ! textureCubeMap //for 3d cards not supporting cubemaps
	{
		map gfx/colors/celshade.tga
		blendfunc filter
		tcGen environment
	}
	endif
}

