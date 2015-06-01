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

## Use

#### Starting Hectosky

Hectosky should be run from the directory with your reduced Hectospec data.  
To start, enter IDL and execute

`IDL$ hectosky,'PointingName'`

(As before, `PointingName` is the name you gave to the Hectospec pointing.)

Optionally, you can execute

`IDL$ hectosky,'PointingName',/quick`

to tell the program to proceed without stopping to review the sky subtraction
of individual objects.  It will not be entirely automatic, as there is an
interactive portion that cannot be skipped, but it will be faster.  I recommend
not using the `quick` option on the first run through a data set; take advantage of 
Hectosky's display features to get a feel for the sky subtraction quality.

#### Where to save output

By default, Hectosky saves sky-subtracted spectra to `PointingName.skysub/`.  
If a directory with that name already exists in your working
directory, Hectosky will ask

```
Sky-subtracted spectra already exist in PointingName.skysub/
Replace it? (y/n)
```
A `y` answer will delete the contents of the existing folder in preparation
for the new sky-subtracted files.  A `n` answer will prompt you for a new
output folder name:

`Enter new folder name for sky-subtracted results:`

IMPORTANT: The folder name MUST end with a forward slash (`/`), e.g., `NewOutputFolder/`, 
or the files won't save to the right place.

#### Checking for existing sky data

Hectosky begins by checking for 1D sky offset spectra.  E-SPECROAD
splits the multispec object file into 1D spectra, but not the skies,
so Hectosky will do the splitting if needed.  An xgterm window will
open and print its progress (this takes maybe 10 seconds).  There is
no user input during this process.

Before calling GetGoodSky to screen for usable sky spectra, 
Hectosky checks if the list
`PointingName.good_sky_data.txt` already exists in your current directory.  This
allows you to skip the time-consuming process of screening the sky
fibers if you've already done it satisfactorily once.  If the file
exists, you will be asked

`List of good sky spectra detected.  Use this? (y/n)`

A `y` answer tells Hectosky to skip calling GetGoodSky and use the 
information from the existing file instead.  A `n` answer deletes the 
existing file, to be replaced by a new list of workable sky spectra.

Similarly, if there is already a master sky named `PointingName.mastersky.fits`
in your working directory, Hectosky will ask

`Master sky file detected.  Use this? (y/n)`

Again, if you answer `n`, the existing file will be deleted.

#### GetGoodSky & creating the master sky

Hectosky calls its companion program, GetGoodSky, to check the
sky fibers and screen out ones that cannot be used (e.g., because they
landed on a star or have a cosmic ray on top of a nebular line).
GetGoodSky loops over all the sky fibers (all the fibers from a sky
offset pointing *plus* the dedicated sky fibers from the science
pointing) and uses MPFIT to fit the H&alpha; emission line with a
Gaussian.

GetGoodSky will halt and ask for user input if it encounters sky
spectra with one or more of the following properties:

1. A continuum level (default between 5150 and 5400 &#x212b;) more than 2&sigma; 
above the median.  This often signals a sky contaminated by
stellar light.

2. Central wavelength of the H&alpha; fit is more than 3&sigma; away
from the median.  This can indicate the presence of a cosmic ray or
other oddity in the H&alpha; line.

3. For spectra taken with the 600 lpm grating, 
a full width half max (FWHM) of the H&alpha; fit &ge; 3 &#x212b;.
For spectra taken with the 270 lpm grating, a FWHM more than 1&sigma; away from the
median.  This usually signals a poorly-fit H&alpha; line and is
primarily of interest if you want reasonably accurate H&alpha;
measurements in order to make an H&alpha; map.  If you don't care about
the accuracy of the H&alpha; equivalent width measurements, you can
mostly ignore this warning.

4. A positive equivalent width, i.e., H&alpha; has been fit as an
absorption line.  Usually these are clear stellar contaminants.

(The means/medians/sigmas are calculated from all the sky spectrum from
that pointing.)

GetGoodSky will plot the full flagged spectrum with the Gaussian fit
of H&alpha; overplot in red, print the reasons the spectrum was flagged
to the termainal, and ask the user the following questions.  Questions must be
answered with a `y` (for yes) or `n` (for no), followed by the `Enter` key.
If you type in anything else and hit `Enter`, the program will repeat
the question and otherwise do nothing.

`Zoom in on H-alpha line? (y or n)`

A `y` will replot the spectrum and the Gaussian fit between 6200 and
6900 &#x212b;.  The dashed line shows where the center of the H&alpha; line is
expected to be based on the mean of the fits to all the skies.
A `n` will send you to the next question without replotting.  

`Keep this spectrum as is? (y or n)`

If, in your judgement, there is nothing wrong with the sky spectrum and you do not wish to
refit the H&alpha; line, hit `y`.  GetGoodSky will consider this sky
spectum usable and continue its loop over the skies.  A `n` response
will send you to the next question.

`Refit in SPLOT? (y or n)`

If the sky spectrum is good but the Gaussian fit is poor (and you want
to improve it), or if you want to be able to zoom in further on the
spectrum before making a decision, hit `y`.  This will open an IRAF
graph window with the sky spectrum plotted.  All SPLOT functions work
as usual.  Use the 'd' key and subsequent prompts to fit the H&alpha;
line.  You can repeat the fit as often as you like; GetGoodSky will
take the last one.  

When you're satisfied with your fit in SPLOT (or have decided that the
spectrum is unusable), hit 'q' to hit SPLOT and return to the IDL
terminal.  GetGoodSky will print the parameters of your fit and ask

`Did you successfully fit the line? (y or n)`

A `y` will mark the sky as usable and keep your fit; a `n` will mark
the sky as unusable and move on.

If you chose not to refit with SPLOT, you will be prompted with a
final question:

`Set EW to zero? (y or n)`

This option exists for the few cases I have encountered where, within
the noise, there is no H&alpha; line emission but the sky is still
usuable for sky subtraction.  Answering `y` will
mark the sky as usuable; `n` will mark the sky as unusable.

When GetGoodSky has fit and checked all the sky spectra, it prints the
list of usable skies to a file (`PointingName.good_sky_data.txt`) 
and returns control to Hectosky.
Hectosky then makes a median master sky out of the good sky fibers, scaling
by exposure time where necessary.  The master sky is saved as 
`PointingName.mastersky.fits`.

#### Fitting nebular lines in the master sky

Next, Hectosky fits the nebular sky emission lines in the master sky,
starting with H&alpha;.  The fitting routine sometimes has trouble
getting the H&alpha;fit right the first time, especially for the
lower-resolution 270 gpm spectra.  If you answer `n` to the question

`Use this fit to the H-alpha line? (y/n) `

a SPLOT window will open up, where you can manually refit the line,
again using the 'd' key and subsequent commands.  When you quit out of
SPLOT, Hectosky will refit the H&alpha; line based on your fit and
repeat its question.  If you are satisfied with the fit to the H&alpha;
line in the master sky at this point, the program will move on to the rest of the
nebular lines.

Hectosky will try to fit all of the following lines that fall within
the wavelength range of your spectra:

- H&alpha;, H&beta;
- [NII] &lambda;&lambda; 6547, 6584
- [SII] &lambda;&lambda; 6717, 6731
- [ArIII] &lambda; 7135
- He I &lambda;&lambda; 5876, 6678, 7065
- [OIII] &lambda;&lambda; 4959, 5007

Except for H&alpha;, you do not have the option to refit these lines.
If the fit is poor or the line does not clearly appear in the master
sky spectrum, answering `n` to

`Include the fit to this line? (y/n)`

means that line will not be fit as a nebular line for sky subtraction.

NOTE: Pay careful attention to the dotted vertical line showing the
expected central wavelength for the line in question.  If the line is
very small, sometimes Hectosky will fit to a nearby sky emission line, 
and the fit will look good, but be wrong.

ALSO NOTE: At the resolution of Hectospec, the emission lines are not
always perfectly Gaussian.  Do not worry if there is a slight
deviation or if the Gaussian fit appears to have a slightly higher
peak flux than the line in the master sky.  This effect will
largely be cancelled out by the second line fitting later in the
program.

After going through the nebular line fits, Hectosky plots the master
sky spectrum with all including nebular line fits overplotted.  The
TOP panel shows the full wavelength range, while the BOTTOM panel
zooms in on the 6500-6800 &#x212b; region to emphasize the H&alpha;, [NII],
and [SII] fits.  The terminal will say: 

```
When you have finished reviewing the master sky, 
hit ENTER to continue to sky subtraction of individual spectra. 
```


