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

## Requirements

* IRAF (available at http://iraf.noao.edu/)
* The `hectospec` package for IRAF (available at http://tdc-www.harvard.edu/iraf/hectospec/)
* MPFIT, an IDL-based curve fitting program created by Craig Markwardt (http://cow.physics.wisc.edu/~craigm/idl/fitting.html)

## Installation

The Hectosky package has IDL and bash components.  

The IDL components of Hectosky are the programs:

- `hectosky.pro` (and its variations)
- `getgoodsky.pro`

These should be placed in a folder in your IDL path.  I have a folder
in my home directory called `idl` and a line in my `.bashrc` that adds
this directory to my IDL_PATH:

`IDL_PATH=$IDL_PATH:+$HOME/idl`

The bash components are the programs:

- `callhecto`
- `callimutil`
- `calloned`

These should be placed in a folder in your bash PATH.  I have a folder
in my home directory called `bin` and a line in my `.bashrc` that adds
this directory to my PATH:

`PATH=$PATH:+$HOME/bin`

Setting up these three scripts is the most complicated part of getting
Hectosky to run and requires a basic understanding of your IRAF
installation.  There exists a way to query the required parameters
within the bash script, so that they don't all have to be set
manually, but this version of Hectosky does not have that capability.

Open `calloned` in your favorite text editor.  You will need to edit
two lines of the header as follows:

`#!/iraf/iraf/bin.linux64/ecl.e -f`

Replace the path above with the path to the `ecl.e` file of your IRAF
distribution.

`set	arch		= .linux64`

Replace the '.linux64' with your system's architecture.  To determine what 
system architecture your IRAF installation is using, enter the IRAF `cl`
environment and execute:

`cl> show arch`

To test if the parameters are correctly set on your system, go to a
directory with a FITS spectrum and execute (replacing "spectrum" with the
name of your file):

`$ xgterm -e calloned splot spectrum.fits`

If the `splot` command works and you see your spectrum plotted, then you're good 
to go.  If not, open an `xgterm` terminal and execute:

`$ calloned splot spectrum.fits`

This will allow you to see any error messages that result.  When I
first set up these programs on my computer, there was something weird
about the IRAF distribution (v2.14.1) that was causing problems: IRAF was
looking for the `x_onedspec.e` file in the wrong directory.  I copied
`x_onedspec.e` to the folder it was searching, and the problem was
solved.  (I haven't had this problem with IRAF v2.16.)

Once you have `calloned` working, edit
`callhecto` and `callimutil` in the same way.  The Hectosky package is now ready to run.
