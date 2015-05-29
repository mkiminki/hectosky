# HECTOSKY

Sky subtraction routines for Hectospec observations.

## Introduction

Hectosky is an IDL-based program for sky subtraction of spectra taken
with the multi-fiber spectrograph [Hectospec](http://www.mmto.org/node/55).  Hectosky optimizes the
subtraction of spatially-variable nebular emission lines while
minimizing the noise introduced by subtracting the sky emission lines.

HECTOSKY is designed to be run after the E-SPECROAD data reduction
pipeline, which was written by Juan Cabanela at Minnesota State University 
and is available at:

http://astronomy.mnstate.edu/cabanela/research/ESPECROAD/  

E-SPECROAD
performs its own basic sky subtraction and places the results in
`skysub_PointingName` (where `PointingName"` is the name of a Hectospec
pointing, found in the raw file names as `PointingName.NNNN.fits`.).  
Do not use the sky subtraction
from E-SPECROAD if you are using Hectosky.  Instead, Hectosky will use
the multispec files `PointingName.ms.fits` and `skyoff_PointingName.fits`,
along with the 1D spectra in the directory `1d.PointingName/` and the
map files `PointingName_map` and `skyoff_PointingName_map`.

The code for Hectosky and its associated programs is heavily
commented, so if you run into something not described in this file,
looking at the code may be helpful.

Questions and bug reports should be directed to Megan Kiminki at
<mbagley@email.arizona.edu>.

## Sky Subtraction Outline

What Hectosky does, in brief:

1. Screens sky fibers for any usuable skies (e.g. sky fibers that
landed on a star).

2. Combines all usable skies into a **master sky**.  

3. Fits nebular emission lines like H-alpha in the master sky and
subtracts the fits to create a **master-minus-nebular** template.

4. Subtracts the master-minus-nebular spectrum from the individual sky
spectrum closest on the sky to a science object, creating a **nebular-lines-only** sky spectrum.

5. Fits the nebular lines in the nebular-lines-only spectrum.  

6. Adds the lines fit from the nebular-lines-only to the master-minus-nebular
to create a **synthetic sky**.  The synthetic sky thus
consists of the continuum and OH, O<sub>2</sub> and other sky emission lines
from the master sky, plus the nebular lines corresponding to their
strength in the nearest individual sky spectrum.

7. Subtracts the synthetic sky from the science object spectrum. 
