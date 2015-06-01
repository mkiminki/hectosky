pro hectosky_s2comp,pointname,quick=quick

; PURPOSE:  Do sky subtraction of spectra taken with the Hectospec
;           multifiber spectrograph.  The algorithm is designed to 
;           maximize the signal-to-noise of the subtraction of 
;           atmospheric emission lines while accurately subtracting 
;           nebular emission lines (from HII regions).  
;           ***This version compare the H-alpha subtraction to 
;           [SII] emission instead of [NII]
;
; INPUT:    pointname    ID name of Hectospec pointing/configuration,
;                        e.g., 'W3_14.0_16.5_v3_1'
;           quick        Set this keyword to do sky subtraction 
;                        without pausing to review the master sky or
;                        the individual object spectra.  
; MODIFICATION HISTORY: 
;           2012 Megan M. Kiminki -- Program created.


; CLEAR THE TERMINAL SCREEN.  
; (makes the user interaction cleaner as the program progresses).
spawn,'clear'

; PLOT SETTINGS:
!p.charsize=1.3
!p.multi = [0,1,1] ; Reset if it was anything else.  
angstrom = '( !6!sA!r!u!9 %!6!n!3 )'
; Colors for plotting to the display window.  
; (so I don't have to remember the IDL hex).  
white = 'FFFFFF'xL
red = '0000FF'xL
green = '00FF00'xL
blue = 'FF0000'xL
yellow = '00FFFF'xL
orange = '3378E4'xL
purple = 'FF0066'xL
teal = 'EEEE00'xL
lightblue = 'FF7F00'xL

; CREATE RELEVANT FILES AND DIRECTORY NAMES.  
objmap = pointname + '_map'
skymap = 'skyoff_' + pointname + '_map'
objmsf = pointname + '.ms.fits'
skymsf = 'skyoff_' + pointname + '.ms.fits'
obj1dir = '1d.' + pointname + '/'
sky1dir = '1d.skyoff_' + pointname + '/'
newobjdir = pointname + '.skysub/'
masterskyfile = pointname + '.mastersky.fits'
goodskylist = pointname + '.good_sky_data.txt'

; DETERMINE WHICH GRATING WAS USED FOR THIS CONFIGURATION.  
mainhead = headfits(objmsf,ext=0)
grate = strtrim(sxpar(mainhead,'DISPERSE'),2)
if (grate eq '600_gpm') then begin
   grating = 600
endif else begin
   if (grate eq '270_gpm') then begin
      grating = 270
   endif else begin
      print,'IDL could not determine the grating set-up from the FITS header.'
      grating = 0
      read,'Enter the grating used for this pointing (270 or 600): ',grating
      while ((grating ne 600) and (grating ne 270)) do begin
         read,'Please enter a valid Hectospec grating (270 or 600): ',grating
      endwhile
   endelse
endelse


; SPLIT SKY OFFSET MULTISPEC FILES IF NECESSARY.  
; The E-SPECROAD pipeline splits the on-source multispec files
; but doesn't split the sky offset spectra, so we do it here.  

; First check to see if the 1d files already exist.  
spawn,'ls ' + sky1dir,listing,listerr
; If they don't (i.e. 'ls' returned an error), then split
; the spectra.  
if (listerr ne '') then begin
   spawn,'xgterm -e callhecto hsplit skyoff_' + pointname
endif


; CREATE FOLDER TO HOLD SKY-SUBTRACTED STELLAR SPECTRA.  
; First check to see if the folder already exists.  
spawn,'ls ' + newobjdir,dirlist,dirlisterr
; If LS returns no error, the folder exists.  
if (dirlisterr eq '') then begin
   ; Check if the folder is empty.  
   if (dirlist[0] ne '') then begin
      ; If the folder is not empty, ask if you want to replace it.  
      print,'Sky-subtracted spectra already exist in ' + newobjdir
      re1 = ''
      repeat begin
         read,'Replace it? (y/n) ',re1
      endrep until ((re1 eq 'y') or (re1 eq 'n'))
      if (re1 eq 'y') then begin
         spawn,'rm -rf ' + newobjdir
      endif else begin
         read,'Enter new folder name for sky-subtracted results: ',newobjdir
      endelse
   endif else begin
      ; If the folder exists but is empty, just remove it.  
      spawn,'rmdir ' + newobjdir
   endelse   
endif
; Make the new folder.  
spawn,'mkdir ' + newobjdir



; CHECK FOR A LIST OF USUABLE SKY SPECTRA.  

; Flag to redo the H-alpha measurements and make a new list
; of good skies.  
redoskies = 0

; If the list already exists, ask the user if he/she wants to use it 
; rather than repeat the process.  
spawn,'ls ' + goodskylist,goodreturn,gooderr
; If the error from the LS call is empty, the file exists.  
if (gooderr eq '') then begin
   g1 = ''
   repeat begin
      read,'List of good sky spectra detected.  Use this? (y/n) ',g1
   endrep until ((g1 eq 'y') or (g1 eq 'n'))
   
   ; If they don't want to use the old data, remove the old file and
   ; set the flag to redo the H-alpha measurements and flagging of 
   ; unusable spectra.
   if (g1 eq 'n') then begin
      spawn,'rm -f ' + goodskylist
      redoskies = 1
   endif
endif else begin
   ; If you didn't have a previous list, you can't skip any steps.  
   redoskies = 1
endelse


; CALL THE PROGRAM THAT MEASURES H-ALPHA EQUIVALENT WIDTHS AND 
; SCREENS OUT UNUASABLE SKY SPECTRA.  
; (IF the user needs/wants to run it).  
; This program will overwrite the existing "goodskylist" file.  
if (redoskies ne 0) then begin
   getgoodsky,pointname,goodskylist,grating
endif


; READ IN THE GOOD SKY INFORMATION FROM FILE.  
readcol,goodskylist,format='(A,I,D,D,F,F,F,F)',file_good,ap_good,ra_good,dec_good,exp_good,ew_good,fwhm_good,center_good,/silent


; READ IN ON-SOURCE AND SKY OFFSET MAP FILES.  
readcol,objmap,format='(I,I,A,D,D,D,D,D,D)',delimiter=': ',o_ap,o_flag,o_obj,o_hr,o_min,o_sec,o_deg,o_dmin,o_dsec,/silent
readcol,skymap,format='(I,I,A,D,D,D,D,D,D)',delimiter=': ',s_ap,s_flag,s_obj,s_hr,s_min,s_sec,s_deg,s_dmin,s_dsec,/silent


; SEPARATE SPECTRA INTO 3 CATEGORIES: object, dedicated 
; sky fiber spectrum taken during science exposure, and 
; all used fibers from sky offset exposure.  

; Pull out all actual object spectra.  
sci = where(o_flag eq 1)
sci_ap = o_ap[sci]
sci_obj = o_obj[sci]
; Put together the 1D FITS file names for the objects.  
scifile_temp = string(sci_ap,format='(I3.3)') + '.' + sci_obj + '.fits'
scifile = make_array(n_elements(scifile_temp),/string)
for kk=0,n_elements(scifile_temp)-1 do begin
   scifile[kk] = obj1dir + strjoin(strsplit(scifile_temp[kk],'-',/extract),'m')
endfor
; Convert RA and Dec to decimal degrees.    
sci_ra = (o_hr[sci] + o_min[sci]/60D + o_sec[sci]*3600D)*15D
sci_dec = make_array(n_elements(sci_ra),/double)
for ss=0,n_elements(sci)-1 do begin
   if (o_deg[sci[ss]] ge 0) then begin
      sci_dec[ss] = o_deg[sci[ss]] + o_dmin[sci[ss]]/60D + o_dsec[sci[ss]]/3600D
   endif else begin
      sci_dec[ss] = o_deg[sci[ss]] + o_dmin[sci[ss]]/60D + o_dsec[sci[ss]]/3600D
   endelse
endfor

; Pull out all dedicated sky fibers from the on-source pointing.  
dedsky = where(o_flag eq 0)
dedsky_ap_temp = o_ap[dedsky]
dedsky_obj_temp = o_obj[dedsky]
; Put together the 1D FITS file names for the dedicated sky fibers.  
dedskyfile_tempA = string(dedsky_ap_temp,format='(I3.3)') + '.' + dedsky_obj_temp + '.fits'
dedskyfile_temp = make_array(n_elements(dedskyfile_tempA),/string)
for kk=0,n_elements(dedskyfile_temp)-1 do begin
   dedskyfile_temp[kk] = obj1dir + strjoin(strsplit(dedskyfile_tempA[kk],'-',/extract),'m')
endfor

; Pull out all not-unused fibers from the sky offest pointing.  
offsky = where(s_flag ne 2)
offsky_ap_temp = s_ap[offsky]
offsky_obj_temp = s_obj[offsky]
; Put together the 1D FITS file names for the sky offset fibers.
offskyfile_tempA = string(offsky_ap_temp,format='(I3.3)') + '.' + offsky_obj_temp + '.fits'
offskyfile_temp = make_array(n_elements(offskyfile_tempA),/string)
for kk=0,n_elements(offskyfile_temp)-1 do begin
   offskyfile_temp[kk] = sky1dir + strjoin(strsplit(offskyfile_tempA[kk],'-',/extract),'m')
endfor

; MATCH DEDICATED SKY FIBERS AND SKY OFFSETS TO THE "GOOD" SKY LIST.  

; Match usuable dedicated sky fibers.  
good_onsource = where(file_good eq objmsf)
dedsky_ra = ra_good[good_onsource]
dedsky_dec = dec_good[good_onsource]
dedsky_exp = exp_good[good_onsource]
dedsky_ew = ew_good[good_onsource]
dedsky_fwhm = fwhm_good[good_onsource]
dedsky_center = center_good[good_onsource]
dedsky_obj = make_array(n_elements(good_onsource),/string)
dedsky_ap = make_array(n_elements(good_onsource),/int)
dedskyfile = make_array(n_elements(good_onsource),/string)
for gg=0,n_elements(good_onsource)-1 do begin
   dedsky_keep = where(dedsky_ap_temp eq ap_good[good_onsource[gg]])
   dedsky_obj[gg] = dedsky_obj_temp[dedsky_keep]
   dedsky_ap[gg] = dedsky_ap_temp[dedsky_keep]
   dedskyfile[gg] = dedskyfile_temp[dedsky_keep]
endfor

; Match usuable sky offset fibers.  
good_offsource = where(file_good eq skymsf)
offsky_ra = ra_good[good_offsource]
offsky_dec = dec_good[good_offsource]
offsky_exp = exp_good[good_offsource]
offsky_ew = ew_good[good_offsource]
offsky_fwhm = fwhm_good[good_offsource]
offsky_center = center_good[good_offsource]
offsky_obj = make_array(n_elements(good_offsource),/string)
offsky_ap = make_array(n_elements(good_offsource),/int)
offskyfile = make_array(n_elements(good_offsource),/string)
for gg=0,n_elements(good_offsource)-1 do begin
   offsky_keep = where(offsky_ap_temp eq ap_good[good_offsource[gg]])
   offsky_obj[gg] = offsky_obj_temp[offsky_keep]
   offsky_ap[gg] = offsky_ap_temp[offsky_keep]
   offskyfile[gg] = offskyfile_temp[offsky_keep]
endfor


; CALCULATE EXPOSURE TIME SCALING FACTORS FOR SKIES.  
; First get the longest exposure time.  
fulltime = max([dedsky_exp,offsky_exp])
; Then compute ratio between longest time and all sky exposure times.  
dedsky_timefactor = (fulltime[0] / dedsky_exp) 
offsky_timefactor = (fulltime[0] / offsky_exp)


; MAKE THE THREE CATEGORIES INTO TWO:
; Put the objects and dedicated sky fibers into one category, 
; the group to do sky subtraction on (the dedicated sky fibers are in
; there for testing); put the dedicated sky fibers and the sky offsets
; into another group that makes up the pool of 'skies' to use for 
; subtraction.  

; Group to have sky subtraction done ON it.  
; In older code I referred to this as the "star" group, 
; which I continue to do here for consistency.  
star_ap_temp = [dedsky_ap,sci_ap]
star_obj_temp = [dedsky_obj,sci_obj]
starfile_temp = [dedskyfile,scifile]
star_ra_temp = [dedsky_ra,sci_ra]
star_dec_temp = [dedsky_dec,sci_dec]
; Reorder so these go in aperture order (i.e., so the test skies
; are scattered throughout rather than all at the beginning).  
aporder = sort(star_ap_temp)
star_ap = star_ap_temp[aporder]
star_obj = star_obj_temp[aporder]
starfile = starfile_temp[aporder]
star_ra = star_ra_temp[aporder]
star_dec = star_dec_temp[aporder]

; Group of all skies.  Order doesn't matter for this group.  
sky_ap = [dedsky_ap,offsky_ap]
sky_obj = [dedsky_obj,offsky_obj]
skyfile = [dedskyfile,offskyfile]
sky_ra = [dedsky_ra,offsky_ra]
sky_dec = [dedsky_dec,offsky_dec]
sky_exp = [dedsky_exp,offsky_exp]
sky_ew = [dedsky_ew,offsky_ew]
sky_fwhm = [dedsky_fwhm,offsky_fwhm]
sky_center = [dedsky_center,offsky_center]
sky_timefactor = [dedsky_timefactor,offsky_timefactor]


; MAKE A MASTER SKY - MEDIAN OF ALL GOOD SKY SPECTRA. 
 
; IF you used an old good sky list file, you may also have an old 
; master sky to use, so check and ask if you want to use it. 
spawn,'ls ' + masterskyfile,mskylist,mskyerr
if (redoskies eq 0) then begin
   if (mskyerr eq '') then begin
      ; If the file exists, ask if you want to keep it.  
      k1 = ''
      repeat begin
         read,'Master sky file detected.  Use this? (y/n) ',k1
      endrep until ((k1 eq 'y') or (k1 eq 'n'))
      if (k1 eq 'n') then begin
         ; If they don't want to keep it, change the flag to
         ; indicate to make a new one.
         redoskies = 1
         ; Also delete the old one so there are no overwrite issues in IRAF.
         spawn,'rm -f ' + masterskyfile
      endif
   endif else begin
      ; If the file doesn't exist (meaning LS returned an error),
      ; change the flag so that it will be created.  
      redoskies = 1
   endelse
endif else begin
   ; If the redoskies variable already =1, it means you made a new list
   ; of good sky files and therefore must make a new master median sky.  
   if (mskyerr eq '') then begin
      ; If an old file exists, get rid of it. 
      ; (IRAF won't overwrite an existing file).
      spawn,'rm -rf ' + masterskyfile
   endif 
endelse


; Actually make the master median sky.  
if (redoskies eq 1) then begin

   ; Make file for IRAF to read in good sky filenames.  
   openw,3,'skyfiles.txt'
   for ll=0,n_elements(skyfile)-1 do begin
      printf,3,format='(A)',skyfile[ll]
   endfor
   close,3

   ; Make a file to deal multiply shorter exposure times by the 
   ; appropriate factor.  
   openw,4,'skytimes.txt'
   for tt=0,n_elements(sky_exp)-1 do begin
      printf,4,format='(F)',(sky_timefactor[tt])
   endfor
   close,4
   
   ; Make file of temporary, scaled files for IRAF to create.  
   openw,5,'skyfiles_temp.txt'
   for ss=0,n_elements(skyfile)-1 do begin
      printf,5,format='(A)',skyfile[ss] + '_temp.fits'
   endfor
   close,5

   ; Use IMARITH in IRAF to make files with all skies scaled 
   ; to the full science exposure time.  
   spawn,'xgterm -e callimutil imarith operand1=@skyfiles.txt op="*" operand2=@skytimes.txt result=@skyfiles_temp.txt'

   ; Median-combine the scaled images with SCOMBINE in IRAF.  
   spawn,'xgterm -e calloned scombine @skyfiles_temp.txt ' + masterskyfile + ' group=all combine=median first=yes reject=none scale=none zero=none weight=none'

   ; Remove the list and factor files (not needed anymore).
   spawn,'rm -f skyfiles.txt'
   spawn,'rm -f skytimes.txt'
   spawn,'rm -f skyfiles_temp.txt'

   ; Remove the temporary scaled FITS files.  
   spawn,'rm -rf 1d.*/*_temp.fits'

endif


; Read in the master sky.  
master_sky = mrdfits(masterskyfile,0,header,/silent)

; Pull out wavelength keywords.  
npix = sxpar(header,'NAXIS1')
dispersion = sxpar(header,'CDELT1')
lambda_start = sxpar(header,'CRVAL1')
wavel = findgen(npix)*dispersion + lambda_start




; FIT AND SUBTRACT THE NEBULAR LINES THAT APPEAR IN THE MASTER SKY.  

; Set errors=1 because we don't have ERROR BARS on a spectrum,
; but MPFIT requires them.  
errs=1

; Create the parameter info structure accepted by MPFIT.  
parinfo = replicate({value:0.D, fixed:0, limited:[0,0], limits:[0.D,0]}, 4)

; Recall that for mygauss.pro, 
    ; p[0] = constant offset,
    ; p[1] = mean,
    ; p[2] = standard deviation, and
    ; p[3] = normalization factor.

; Force the normalization factor to be positive.
; This prevents problems that can arise with fitting the
; smaller lines.  
parinfo[3].limited[0] = 1
parinfo[3].limits[0] = 0.00001

; Fix the constant offset at zero for fitting the master sky.
; This seems to be the best way to do this method without
; having to introduce complicated continuum fitting later.  
parinfo[0].fixed = 1
parinfo[0].value = 0.0D


; NEBULAR LINES TO POTENTIALLY FIT:
; (this list does not include every nebular line in the 
; wavelength range, only those that I have seen to appear
; at levels greater than the noise). 
; Ha = H-alpha 6563
; N2blue = [NII] 6548
; N2red = [NII] 6583
; S2blue = [SII] 6716
; S2blue = [SII] 6731
; Ar3 = [ArIII] 7135
; HeIa = HeI 5876
; HeIb = HeI 6678
; HeIc = HeI 7065
; Hb = H-beta 4861
; OIIIa = [OIII] 5007
; OIIIb = [OIII] 4959
; (note: the above abbreviations refer to an older system of keeping
; track of the lines that has been dicontinued for this version of 
; the sky subtraction program).  

; List the lines and their wavelengths.  
; NOTE: The wavelengths are currently optimized for the radial
; velocity W3, meaning they are blueshifted by 1-2 Angstroms.  
; ALSO NOTE: the list can be in any order except that H-alpha MUST be
; listed first.  
linenames_all = ['H-alpha','[NII] 6548','[NII] 6584','[SII] 6717','[SII] 6730','[ArIII] 7135','HeI 5876','HeI 6678','HeI 7065','H-beta','[OIII] 5007','[OIII] 4959']
nebwavs_all = [6562.,6547.,6582.,6716.,6729.,7135.,5874.,6676.,7065.,4861.,5007.,4959.]

; Colors for plotting the lines: set up so lines from the same element
; are the same color.  
ncolors_all = [red,green,green,yellow,yellow,orange,lightblue,lightblue,lightblue,red,purple,purple]
; NOTE: If you add any lines, make sure that LINENAMES_ALL,
; NEBWAVS_ALL, and NCOLORS_ALL all have the same number of elements.  

; Make a cut of which lines to use based on the wavelength range of
; the master sky.  
; The 50-Angstrom buffer from the true wavelength limits is due to the
; fact that my 600 gpm spectra technically start at 5000 Angstroms but
; they definitely don't pick up the [OIII] 5007 line.  
uselines = where((nebwavs_all ge (min(wavel)+50) and (nebwavs_all le (max(wavel)-50))))
linenames = linenames_all[uselines]
nebwavs = nebwavs_all[uselines]
ncolors = ncolors_all[uselines]



; MAKE A STRUCTURE TO HOLD NEBULAR LINE FIT DATA.
    ; name = assigned line name from above.
    ; lambda = approximate wavelength of line center.
    ; estimate = estimate of fit parameters given to MPFIT.
    ; fit = parameter results from MPFIT.
    ; line = the line described by those parameters (i.e., that can
    ;        be plotted against wavelength).  
    ; color = color to use for plotting that line.  
    ; flag = flag of whether that line was used or not (1=used,0=skipped).

nlines = n_elements(linenames) 

neblines = replicate({name:' ', lambda:0.D, estimate:dblarr(4), fit:dblarr(4), line:dblarr(npix), color:'000000'xL, flag:0},nlines)

neblines.name = linenames
neblines.lambda = nebwavs
neblines.estimate[1] = nebwavs
neblines.estimate[3] = 1d+4 ; generic but seems to work
neblines.color = ncolors

; Fit H-alpha first: it is often large enough to be found without
; much problem, and we use it to fix the width of the nebular lines.  
; Initial guess of the standard deviation depends on the grating.  
if (grating eq 270) then neblines[0].estimate[2] = 2.0 else neblines[0].estimate[2] = 1.0
neblines[0].fit = mpfitfun('mygauss',wavel,master_sky,errs,neblines[0].estimate,parinfo=parinfo,/quiet)
neblines[0].line = mygauss(wavel,neblines[0].fit)

; Plot a close-up around H-alpha and confirm that the fit is OK.  
window,0,title='IDL: Master Sky Line Fits'
plot,wavel,master_sky,xr=[neblines[0].lambda-100,neblines[0].lambda+100],xs=1,xtitle='Wavelength ' + angstrom,ytitle='Counts'
oplot,wavel,neblines[0].line,color=neblines[0].color
oplot,[neblines[0].lambda,neblines[0].lambda],[0,max(master_sky)],linestyle=1
xyouts,(neblines[0].lambda + 50),(0.8)*max(master_sky[where((wavel ge neblines[0].lambda-100) and (wavel le neblines[0].lambda+100))]),neblines[0].name,color=neblines[0].color,charsize=2.0

; Confirm with the user that the H-alpha fit is OK.  
; This is a necessary step for the 270 gpm grating data, so
; there is no QUICK option to skip this part.  
spawn,'clear'
hgood = ''
repeat begin
   read,'Use this fit to the H-alpha line? (y/n) ',hgood
endrep until ((hgood eq 'y') or (hgood eq 'n'))

; If the user does not like the fit, refit using input from SPLOT.  
if (hgood eq 'n') then begin

   ; Remove any existing SPLOT log.  
   spawn,'rm -f splot.log'

   usehfit = 0
   while (usehfit eq 0) do begin

      ; Use SPLOT in IRAF to get the initial guess at the H-alpha fit.  
      print,'Use SPLOT to get the initial parameters for the line fit.'
      spawn,'xgterm -e calloned ''splot.save_fi="splot.log"'''
      spawn,'xgterm -e calloned splot ' + masterskyfile
      spawn,'wc -l splot.log',wc_out,wc_out_err

      ; Check that a SPLOT.LOG file exists (if the user
      ; tried to fit the line but quit without doing so, 
      ; the log may not have been created).  
      if (wc_out_err eq '') then begin
         ; Read the results of the SPLOT fit.
         lineread = fix(strmid(wc_out,0,strpos(wc_out,' ')))
         readcol,'splot.log',skipline=lineread[0]-1,format='(F,F,F,F,F,F)',newcent,newcont,newflux,newew,newcore,newfwhm

         ; Use the results from SPLOT to guess at H-alpha.  
         neblines[0].estimate[0] = newcont
         neblines[0].estimate[1] = newcent
         neblines[0].estimate[2] = newfwhm / (2.*sqrt(2.*alog(2.)))

         ; Remove the limits on the constant offset for the first 
         ; round of MPFIT fitting.  
         parinfo[0].fixed = 0

         ; Refit once with MPFIT.  
         neblines[0].fit = mpfitfun('mygauss',wavel,master_sky,errs,neblines[0].estimate,parinfo=parinfo,/quiet)
         neblines[0].line = mygauss(wavel,neblines[0].fit)

         ; Fix the standard deviation and the center from the 
         ; first fit.  
         neblines[0].estimate = neblines[0].fit
         parinfo[1].fixed = 1
         parinfo[1].value = neblines[0].fit[1]
         parinfo[2].fixed = 1
         parinfo[2].value = neblines[0].fit[2]
         
         ; Fix the constant offset back to zero.  
         parinfo[0].fixed = 1 
         parinfo[0].value = 0D
         neblines[0].estimate[0] = 0.

         ; Refit a second time with MPFIT.  
         neblines[0].fit = mpfitfun('mygauss',wavel,master_sky,errs,neblines[0].estimate,parinfo=parinfo,/quiet)
         neblines[0].line = mygauss(wavel,neblines[0].fit)
         
         ; Replot around H-alpha.  
         plot,wavel,master_sky,xr=[neblines[0].lambda-100,neblines[0].lambda+100],xs=1,xtitle='Wavelength ' + angstrom,ytitle='Counts'
         oplot,wavel,neblines[0].line,color=neblines[0].color
         oplot,[neblines[0].lambda,neblines[0].lambda],[0,max(master_sky)],linestyle=1
         xyouts,(neblines[0].lambda + 50),(0.8)*max(master_sky[where((wavel ge neblines[0].lambda-100) and (wavel le neblines[0].lambda+100))]),neblines[0].name,color=neblines[0].color,charsize=2.0

         ; Confirm with the user that the H-alpha fit is OK.  
         spawn,'clear'
         hgood = ''
         repeat begin
            read,'Use this fit to the H-alpha line? (y/n) ',hgood
         endrep until ((hgood eq 'y') or (hgood eq 'n'))
         ; If the fit is good, move on; if not, repeat this process.
         if (hgood eq 'y') then usehfit = 1
      endif else begin
         ; If a SPLOT log was not created, the user needs 
         ; to try the SPLOT fit again.
         print,'Please retry fitting in SPLOT. '
      endelse
   endwhile
endif



; Once you have a successful H-alpha fit, fix the width of 
; the other nebular lines to the width of H-alpha.  
parinfo[2].fixed = 1
parinfo[2].value = neblines[0].fit[2]

; Unfix the center of the lines.  
parinfo[1].fixed = 0


; LOOP OVER THE OTHER NEBULAR LINES:
; Fit them, plot the fit, then ask if you want to use the line. 
for nn=1,nlines-1 do begin

   ; Do the fit.
   neblines[nn].estimate[2] = neblines[0].fit[2]
   neblines[nn].fit = mpfitfun('mygauss',wavel,master_sky,errs,neblines[nn].estimate,parinfo=parinfo,/quiet)
   neblines[nn].line = mygauss(wavel,neblines[nn].fit)

   ; Plot a close-up of the nebular line.  
   plot,wavel,master_sky,xr=[neblines[nn].lambda-100,neblines[nn].lambda+100],xs=1,xtitle='Wavelength ' + angstrom,ytitle='Counts'
   oplot,wavel,neblines[nn].line,color=neblines[nn].color
   oplot,[neblines[nn].lambda,neblines[nn].lambda],[0,max(master_sky)],linestyle=1
   xyouts,(neblines[nn].lambda + 50),(0.8)*max(master_sky[where((wavel ge neblines[nn].lambda-100) and (wavel le neblines[nn].lambda+100))]),neblines[nn].name,color=neblines[nn].color,charsize=2.0

   ; Ask if you want to use the line in sky fitting.  
   ; This is also not an optional step, hence no QUICK 
   ; option to skip it.  
   spawn,'clear'
   f1 = ''
   repeat begin
      read,neblines[nn].name + ': Include the fit to this line? (y/n) ',f1
   endrep until ((f1 eq 'y') or (f1 eq 'n'))

   ; If the user answered 'no', flag the line as one not to fit.
   if (f1 eq 'n') then neblines[nn].flag = 1

endfor

; Remove from consideration the lines the user chose not to include.  
fitto = where(neblines.flag ne 1)
neblines_temp = neblines[fitto]
neblines = neblines_temp
nlines = n_elements(neblines.lambda)


; PLOT THE RESULTS OF FITTING TO THE MASTER SKY.  

; Open a window in which to plot the master sky.
window,0,xsize=720,ysize=720,title='IDL: Master Sky'
!p.multi = [0,1,2]
; Plot master sky.   
plot,wavel,master_sky,xr=[min(wavel),max(wavel)],xs=1,title='Master Sky: Nebular Line Fits',xtitle='Wavelength ' + angstrom,ytitle='Counts'
; Overplot the nebular lines fits.  
for nn=0,nlines-1 do begin
   oplot,wavel,neblines[nn].line,color=neblines[nn].color
endfor

; Repeat the above plot, but zoom in on the area around H-alpha.  
plot,wavel,master_sky,xr=[6500,6800],xs=1,title='Master Sky: Close-Up Around H-Alpha',xtitle='Wavelength ' + angstrom,ytitle='Counts'
for nn=0,nlines-1 do begin
   oplot,wavel,neblines[nn].line,color=neblines[nn].color
endfor


; Subtract the nebular line fits from the master sky.  
; This is what will be subtracted from the individual sky spectra.  
master_noneb = master_sky
for nn=0,nlines-1 do begin
   master_noneb = master_noneb - neblines[nn].line
endfor


; Pause for review of the master sky.  
if (not keyword_set(quick)) then begin
   spawn,'clear'
   w1 = ''
   print,'When you have finished reviewing the master sky, '
   read,'hit ENTER to continue to sky subtraction. ',w1
endif





; LOOP OVER OBJECT SPECTRA.  
nstar = n_elements(star_ra)
for jj=0,nstar-1 do begin

   spawn,'clear'

   ; Find the object's sky offset, if it exists.  
   closest = where((strmid(skyfile,0,5) eq '1d.sk') and (sky_ap eq star_ap[jj]))
   nooff = 0

   ; If the offset doesn't exist, find the nearest sky fiber.  
   if (closest eq -1) then begin

      ; Set flag that this one is not using its sky offset.  
      nooff = 1
      
      dist = sqrt((sky_ra - star_ra[jj])^2 + (sky_dec - star_dec[jj])^2)
      closest = where(dist eq min(dist))
      ; If more than one sky is equally close, just pick the 
      ; first one on the list (this happens very rarely and seems to
      ; be the best way to deal with the issue without making things
      ; very complicated).  
      closest = closest[0]

   endif

   
   ; Read in spectrum of nearest good sky fiber.  
   real_sky = mrdfits(skyfile[closest],0,header,/silent)

   ; Pull out the exposure time of the nearest sky fiber.  
   real_time = sxpar(header,'EXPTIME')

   ; Multiply the fluxes of the nearest sky fiber if necessary to
   ; match the "exposure time" of the master sky.  
   real_sky = (fulltime/real_time) * temporary(real_sky)

   ; Pull out wavelength keywords for nearest sky fiber.  
   npix = sxpar(header,'NAXIS1')
   dispersion = sxpar(header,'CDELT1')
   lambda_start = sxpar(header,'CRVAL1')
   ; Calculate wavlength for this sky spectrum.  
   this_wavel = findgen(npix)*dispersion + lambda_start
   ; Interpolate nearest sky spectrum to the same wavelength 
   ; grid as the master sky.  
   real_sky_temp = interpol(real_sky,this_wavel,wavel)
   real_sky = real_sky_temp ; Change variable name back to what is used later on.

   ; Subtract (master sky - nebular lines) from the nearest
   ; good sky spectrum.  
   sky_resid = real_sky - master_noneb


   ; FIT THE NEBULAR LINES THAT APPEAR IN THE RESIDUAL SKY SPECTRUM.  

   ; Reset the parameter info structure accepted by MPFIT.  
   parinfo = replicate({value:0.D, fixed:0, limited:[0,0], limits:[0.D,0]}, 4)

   ; Force the normalization factor to be positive.
   ; This prevents problems that can arise with fitting the
   ; smaller lines.  
   parinfo[3].limited[0] = 1
   parinfo[3].limits[0] = 0.00001

   ; Reset the structure that holds nebular line fit data.  
   neblines_master = neblines
   neblines = replicate({name:' ', lambda:0.D, estimate:dblarr(4), fit:dblarr(4), line:dblarr(npix), color:'000000'xL},nlines)

   neblines.name = neblines_master.name
   neblines.lambda = neblines_master.lambda
   neblines.estimate[1] = neblines_master.lambda
   neblines.estimate[3] = 1d+4  ; generic but seems to work
   neblines.color = neblines_master.color

   ; Fit H-alpha first again.  
   ; Initial guess of standard deviation depends on grating.  
   if (grating eq 270) then neblines[0].estimate[2] = 2.0 else neblines[0].estimate[2] = 1.0
   neblines[0].fit = mpfitfun('mygauss',wavel,sky_resid,errs,neblines[0].estimate,parinfo=parinfo,/quiet)
   neblines[0].line = mygauss(wavel,neblines[0].fit)

   ; Fix the width of the other nebular lines to the width of H-alpha.  
   parinfo[2].fixed = 1
   parinfo[2].value = neblines[0].fit[2]

   ; Fit the rest of the nebular lines in the residual sky.  
   for nn=1,nlines-1 do begin
      neblines[nn].estimate[2] = neblines[0].fit[2]
      neblines[nn].fit = mpfitfun('mygauss',wavel,sky_resid,errs,neblines[nn].estimate,parinfo=parinfo,/quiet)
      neblines[nn].line = mygauss(wavel,neblines[nn].fit)
   endfor



   ; CREATE SYNTHETIC SKY: (MASTER - NEBULAR LINES) + NEBULAR LINE
   ; FITS FOR THE NEAREST SKY SPECTRUM.  
   ; Add nebular line fits to (master sky - nebular lines),
   ; but don't add zero-level.  
   synth_sky = master_noneb
   for nn=0,nlines-1 do begin
      synth_sky = synth_sky + neblines[nn].line - neblines[nn].fit[0]
   endfor

   ; Compute median zero level of line fits.  
   medzero = median(neblines.fit[0])
   ; Add median zero level to synthetic sky.  
   synth_sky = synth_sky + medzero
   ; Calculate difference between synthetic sky and real nearest sky.  
   diff_synth = real_sky - synth_sky 


   ; SUBTRACT SYNTHETIC SKY FROM OBJECT SPECTRUM.  
   ; Read in object spectrum.  
   obj_spec = mrdfits(starfile(jj),0,header_obj,/silent)

   ; Pull out wavelength keywords for object spectrum.  
   npix = sxpar(header_obj,'NAXIS1')
   dispersion = sxpar(header_obj,'CDELT1')
   lambda_start = sxpar(header_obj,'CRVAL1')
   ; Calculate wavelength grid for object.  
   wavel_obj = findgen(npix)*dispersion + lambda_start
   
   ; Interpolate synthetic sky to same wavelength grid as object.  
   synth_sky_temp = interpol(synth_sky,wavel,wavel_obj)

   ; Do the subtraction.  
   obj_nosky = obj_spec - synth_sky



   ; PLOT RESULTS OF SYNTHESIZING SKY AND DOING SKY SUBTRACTION.  

   ; Open window for plotting individual sky spectra and skies.  
   win_title = 'IDL: Sky Subtraction of Aperture ' + strtrim(string(star_ap[jj]),2)
   window,0,xsize=1080,ysize=720,title=win_title
   !p.multi = [0,2,2,0,1]

   ; Plot the real sky, synthetic sky, and the difference between them.
   plot,wavel,real_sky,xr=[min(wavel),max(wavel)],xs=1,title='Sky Spectrum For This Object'
   oplot,wavel_obj,synth_sky,color=red
   oplot,wavel,diff_synth,color=green
   al_legend,['Real Sky','Synthetic Sky','Residuals'],linestyle=[0,0,0],color=[white,red,green],/right,/top,charsize=1

   ; Plot the real sky, synthetic sky, and the difference between them,
   ; and zoom in on H-alpha.  
   xr_bot = [6525,6750]
   inxr = where((wavel ge 6525) and (wavel le 6750))
   plot,wavel,real_sky,xr=xr_bot,xs=1,yr=[min(diff_synth[inxr]),max(obj_spec[inxr])],title='Sky Spectrum Around H!7a!3'
   oplot,wavel_obj,synth_sky,color=red
   oplot,wavel,diff_synth,color=green
   ; Alert user if the sky offset was not used.
   if (nooff ne 0) then begin
      xyouts,6600,max(obj_spec)*(0.8),'NOT SKY OFFSET'
   endif


   ; Plot the object spectrum with and without sky subtraction.  
   plot,wavel,obj_spec,xr=[min(wavel),max(wavel)],xs=1,title='Object Spectrum'
   oplot,wavel,obj_nosky,color=teal
   al_legend,['Before Sky Subtraction','With Sky Subtraction'],linestyle=[0,0],color=[white,teal],charsize=1

   ; Plot the object spectrum with and without sky subtraction.  
   ; and zoom in on H-alpha.
   plot,wavel_obj,obj_spec,xr=xr_bot,xs=1,yr=[min(diff_synth[inxr]),max(obj_spec[inxr])],title='Object Spectrum Around H!7a!3'
   oplot,wavel_obj,obj_nosky,color=teal


   ; MAKE FITS FILE WITH SKY-SUBTRACTED SPECTRUM.  
   ; Doesn't need to be done if the 'object' is a dedicated sky fiber
   ; (which were left in to test subtraction).
   if (star_obj[jj] ne 'sky') then begin

      ; Name of file, in new object directory.  
      newname = newobjdir + string(star_ap[jj],format='(I3.3)') + '.' + star_obj[jj] + '.fits'

      ; Add a HISTORY comment to the FITS file indicating sky
      ; subtraction was done at the current date and time.  
      subtime = systime(/utc)
      sxdelpar,header_obj,''    ; The FITS headers for some reason had a lot
                                ; of blank lines at the end.  
                                ; This line gets rid of them.  
      sxaddhist,'sky subtraction performed ' + subtime,header_obj

      ; Write the FITS file.  
      mwrfits,obj_nosky,newname,header_obj,/create

   endif


   ; Pause for review of sky subtraction of this object.  
   if (not keyword_set(quick)) then begin

      print,'This is: ' + star_obj[jj]  ; Print object name.  
      p1 = ''
      read,'Hit ENTER to continue to the next object. ',p1

   endif


endfor



return
end
; Inlcude statement: compiles program that will be called by this one.  
@getgoodsky.pro
