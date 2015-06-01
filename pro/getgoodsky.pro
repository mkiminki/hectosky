pro getgoodsky,pointname,goodskylist,grating
  
; PURPOSE: Measure equivalent widths (EWs) of H-alpha in Hectospec
;          sky fibers and flag unusable sky spectra.  
;
; USE:     Called by HECTOSKY.pro & its variations.
;
; INPUT:   pointname     ID name of Hectospec pointing/configuration,
;                        e.g., 'W3_14.0_16.5_v3_1'
;          goodskylist   Name of file to which to print results.  
;          grating       Hectospec grating used for these observations:
;                        options are 270 or 600 (gpm).  
;
; MODIFICATION HISTORY: 
;          2012 Megan M. Kiminki -- Program created.


; SOME THINGS FOR PLOTTING.  
angstrom = '( !6!sA!r!u!9 %!6!n!3 )'
!p.multi=[0,1,1] ; Resets in case it wasn't on this.  

; CREATE RELEVANT FILES AND DIRECTORY NAMES.  
objmap = pointname + '_map'
skymap = 'skyoff_' + pointname + '_map'
objmsf = pointname + '.ms.fits'
skymsf = 'skyoff_' + pointname + '.ms.fits'
; Put filenames and maps into a list.
; (to work with how the program is structured).  
filename = [objmsf,skymsf]
mapname = [objmap,skymap]


; CLEAR OLD SPLOT.LOG.
; (Not strictly necessary, but prevents the SPLOT log from
; getting really long if the program is run multiple times).  
spawn,'rm -f splot.log'


; MAKE ARRAYS TO HOLD EVERYTHING. 
hecto_ap = 300  ; Total number of Hectospec fibers per configuration.  
nspec = n_elements(filename)*hecto_ap
; The '_all' indicates that ALL skies are included.  
ra_all = make_array(nspec,/double)
dec_all = make_array(nspec,/double)
flag_all = make_array(nspec,/int)
key_all = make_array(nspec,/string)
file_all = make_array(nspec,/string)
aper_all = make_array(nspec,/int)
map_all = make_array(nspec,/string)
exp_all = make_array(nspec,/long)


; LOOP OVER THE MULTISPEC FITS FILES.  
for ff=0,n_elements(filename)-1 do begin
   
   ; Read in spectral data for all apertures.  
   inspec = mrdfits(filename[ff],0,header,/silent)

   ; Read in matching map file - get RA and dec for all apertures.  
   readcol,mapname[ff],format='(I,I,A,D,D,D,D,D,D)',delimiter=': ',ap,flag,obj,hr,min,sec,ddeg,dmin,dsec,/silent

   ; Pull out a two-letter key to indicate on-source of sky
   ; offset pointing.  
   key = strmid(mapname[ff],0,2)

   ; Pull out the exposure time.
   exptime = sxpar(header,'EXPTIME')

   ; Loop over each aperture and sort things into arrays.  
   startind = ff*hecto_ap
   for aa=0,hecto_ap-1 do begin

      flag_all[startind+aa] = flag[aa]
      key_all[startind+aa] = key
      file_all[startind+aa] = filename[ff]
      aper_all[startind+aa] = ap[aa]
      map_all[startind+aa] = mapname[ff]
      exp_all[startind+aa] = exptime
      
      ; Convert RA and Dec into decimal degrees.  
      ra_all[startind+aa] = (hr[aa] + min[aa]/60D + sec[aa]/3600D)*15D
      if (ddeg[aa] ge 0) then begin
         dec_all[startind+aa] = ddeg[aa] + dmin[aa]/60D + dsec[aa]/3600D
      endif else begin
         dec_all[startind+aa] = ddeg[aa] - dmin[aa]/60D - dsec[aa]/3600D
      endelse

   endfor

endfor



; SCREEN OUT FIBERS WE KNOW WE DON'T WANT:
; All unused fibers from any pointing (because we don't know what 
; the fell on and because they weren't fully reduced) and all object
; fibers from on-source pointings (because they aren't skies).  
notsky = where(((flag_all eq 2) or ((key_all ne 'sk') and (flag_all eq 1))),complement=keep)
nkeep = n_elements(keep)



; FIT THE NEBULAR H-ALPHA LINE AND MEASURE PART OF THE CONTINUUM. 
; (the continuum measure helps catch stars or bad data).  

; Make some more arrays.  
contin_keep = make_array(nkeep,/double)
offset_keep = make_array(nkeep,/double)
cent_keep = make_array(nkeep,/double)
sigma_keep = make_array(nkeep,/double)
norm_keep = make_array(nkeep,/double)

; Clear the terminal and let the user know what is going on.
spawn,'clear'
print,'Measuring EWs with MPFIT...'

; Loop over all the "kept" (i.e., actual sky) fibers.  
for jj=0,nkeep-1 do begin

   ; Read in the appropriate line of the appropriate FITS file.  
   inspec = readfits(file_all[keep[jj]],header,startrow=(aper_all[keep[jj]]-1),numrow=1,/silent)
   
   ; Pull out wavelength keywords.  
   npix = sxpar(header,'NAXIS1')
   dispersion = sxpar(header,'CDELT1')
   lambda_start = sxpar(header,'CRVAL1')
   wavel = findgen(npix)*dispersion + lambda_start

   ; Select the wavelength range to be used as the continuum.  
   ; The default is between 5150 and 5400 Angstroms, because this
   ; is a relatively line-free section of sky that appears in 
   ; both the 270 gpm spectra and my 600 gpm spectra (which are
   ; centered at 6300 Angstroms).  
   cmin = 5150
   cmax = 5400
   ; Since 600 gpm spectra can be centered at different wavelengths,
   ; check that the default limits work; if they don't work, prompt
   ; the user for another continuum range.  
   if ((cmin lt min(wavel)) or (cmax gt max(wavel))) then begin
      repeat begin
         print,'The range for measuring the continuum lies outside the wavelength range of these spectra.  You will need to enter a new range. '
         read,'Enter the minimum wavelength for the continuum range: ',cmin
         read,'Enter the maximum wavelength for the continuum range: ',cmax
      endrep until ((cmin ge min(wavel)) and (cmax le max(wavel)))
   endif

   ; Calculate the median flux value over the designated 
   ; continuum range.  
   where_cont = where((wavel ge cmin) and (wavel le 5400))
   contin_keep[jj] = median(inspec[where_cont])

   ; Set errors=1 because we don't have ERROR BARS on a spectrum,
   ; but MPFIT requires them.  
   errs=1

   ; Create the parameter info structure accepted by MPFIT.  
   parinfo = replicate({value:0.D, fixed:0, limited:[0,0], limits:[0.D,0]}, 4)

   ; Recall that for MYGAUSS.PRO, 
      ; p[0] = constant offset,
      ; p[1] = mean,
      ; p[2] = standard deviation, and
      ; p[3] = normalization factor.

   ; Only fit to a region around H-alpha.  
   wfit = where((wavel ge 6400) and (wavel le 6800))
   
   ; Determine the constant offset for this sky spectrum by taking the
   ; median flux values of two small regions on either side of 
   ; H-alpha that don't contain large OH or other emission lines.  
   bkrange = where(((wavel ge 6430) and (wavel le 6450)) or ((wavel ge 6750) and (wavel le 6770)))
   offset_keep[jj] = median(inspec(bkrange))
   
   ; Fix the constant offset to this value (otherwise MPFIT 
   ; uses the nearby OH lines and comes up with too high a 
   ; background level).
   parinfo[0].fixed = 1
   parinfo[0].value = offset_keep[jj]

   ; Initial guess of the width of the H-alpha line depends on the grating.
   if (grating eq 270) then sig_guess = 2.0 else sig_guess = 1.0

   ; Initial guess at the fit of the H-alpha line.  
   fit_guess = [offset_keep[jj],6562.,sig_guess,(max(inspec(wfit))-offset_keep[jj])]

   ; (Attempt to) fit the H-alpha line.  
   ha_pars = mpfitfun('mygauss',wavel(wfit),inspec(wfit),errs,fit_guess,parinfo=parinfo,/quiet)

   ; Store fit parameters.
   cent_keep[jj] = ha_pars[1]
   sigma_keep[jj] = ha_pars[2]
   norm_keep[jj] = ha_pars[3]

endfor

; Convert some parameters to quantities we care more about.
fwhm_keep = 2.*sqrt(2.*alog(2.))*sigma_keep
ew_keep = -(!pi*norm_keep)/offset_keep  ; Recall the EWs are <0 for emission lines.

; CHECK FOR OTHER THINGS WE DON'T WANT: high continuum levels
; that might indicate a star; Gaussians centered away from the
; wavelength of H-alpha; positive equivalent widths indicating 
; absorption lines; very high FWHM values that indicate an incorrect fit.

; Marker of which fibers to keep (=0 means keep, =1 means remove).
sflag_keep = make_array(nkeep,/int,value=0)

; Statistics of the centers of the fit to H-alpha.   
meanclip,cent_keep,meancent,sigcent,clipsig=3,maxiter=5

; Statistics of H-alpha FWHMs.
meanclip,fwhm_keep,meanfwhm,sigfwhm,clipsig=3,maxiter=5

; Loop over all sky fibers.
for jj = 0,nkeep-1 do begin

   spawn,'clear'

   ; Statistics for the continuum levels of that pointing. 
   ; (absolute value of continuum depends on exposure time, clouds, etc.)
   same_exp = where(map_all[keep] eq map_all[keep[jj]])
   medcontin = median(contin_keep[same_exp])
   sigcontin = stddev(contin_keep[same_exp])

   ; Identify signs that a sky fiber is "bad" or needs to be
   ; checked out further.  
   problem = 0
   
   ; Flag things with 2-sigma deviations in continuum level (high only).
   if (contin_keep[jj] gt (medcontin+(2*sigcontin))) then begin
      print,'*****This sky has a high continuum level.'
      problem = 1
   endif 

   ; Flag things with 3-sigma deviations in Gaussian center (both sides).
   if (abs(cent_keep[jj]-meancent) gt (3*sigcent)) then begin
      print,'*****The Gaussian fit is not centered on H-alpha.'
      print,'Center = ',cent_keep[jj]
      print,'EW = ',ew_keep[jj]
      problem = 1
   endif

   ; Flag things with 1-sigma deviations in FHWM (high only). 
   if (grating eq 600) then begin
      fwlimit = 3.0   ; Hard-coded limit --> works better than trying
                      ; to use distribution for this grating's data.  
   endif else begin
      fwlimit = meanfwhm + sigfwhm 
   endelse
   if (fwhm_keep[jj] ge fwlimit) then begin
      print,'*****The FWHM of the fit is very large.'
      print,'FWHM = ',fwhm_keep[jj]
      print,'EW = ',ew_keep[jj]
      problem = 1
   endif

   ; Flag things with positive equivalent widths (absorption lines).
   if (ew_keep[jj] gt 0.0) then begin
      print,'*****This sky has H-alpha in absorption.'
      ; This one gets a special problem flag because this fit is DEFINITELY
      ; unacceptable for a sky, whereas the others could just be on the
      ; tails of a distribution.  There is no option to keep the skies
      ; with positive EWs as they are, because they must either be
      ; refit or discarded.  
      problem = 2
   endif


   ; REVIEW SPECTRA OF PROBLEM SKIES.  
   if (problem gt 0) then begin

      ; Read in the appropriate fits file.  
      inspec = readfits(file_all[keep[jj]],header,startrow=(aper_all[keep[jj]]-1),numrow=1,/silent)
      ; Pull out wavelength keywords.  
      npix = sxpar(header,'NAXIS1')
      dispersion = sxpar(header,'CDELT1')
      lambda_start = sxpar(header,'CRVAL1')
      wavel = findgen(npix)*dispersion + lambda_start

      ; Plot spectrum for inspection.
      window,0,title='IDL: Flagged Spectrum'
      plot,wavel,inspec,xs=1,xtitle='Wavelength '+angstrom,ytitle='Counts'


      ; Overplot the fit produced by MPFIT.  
      haline = mygauss(wavel[wfit],[offset_keep[jj],cent_keep[jj],sigma_keep[jj],norm_keep[jj]])
      oplot,wavel[wfit],haline,color='0000FF'x

      ; Ask if you want to zoom in on the H-alpha line.  
      zoom = ''
      repeat begin
         read,'Zoom in on H-alpha line? (y or n) ',zoom
      endrep until ((zoom eq 'y') or (zoom eq 'n'))

      ; If desired, zoom in on the H-alpha line.
      if (zoom eq 'y') then begin
         plot,wavel,inspec,xs=1,xr=[6200,6900],xtitle='Wavelength '+angstrom,ytitle='Counts'
         oplot,wavel[wfit],haline,color='0000FF'x
         ; Overplot where H-alpha should be centered.  
         oplot,[meancent,meancent],[-100,1e+6],linestyle=1,thick=1
      endif
 
      ; Ask if you want to keep the spectrum without refitting.
      want = ''
      if (problem eq 1) then begin
         repeat begin
            read,'Keep this spectrum as is? (y or n) ',want
         endrep until ((want eq 'y') or (want eq 'n'))
      endif else begin
         want = 'n'
      endelse  

      ; Continue if you didn't want to keep the original fit.  
      if (want eq 'n') then begin

         ; Ask if you want to refit with SPLOT.
         refit = ''
         repeat begin
            read,'Refit in SPLOT? (y or n) ',refit
         endrep until ((refit eq 'y') or (refit eq 'n'))
         
         ; (Try to) refit the spectrum if desired.
         if (refit eq 'y') then begin
            spawn,'xgterm -e calloned ''splot.save_fi="splot.log"'''
            spawn,'xgterm -e calloned splot '+ file_all[keep[jj]] + string(aper_all[keep[jj]])
            spawn,'wc -l splot.log',wc_out,wc_out_err

            ; Check that a SPLOT.LOG file exists (if the user
            ; tried to fit the line but quit without doing so, 
            ; the log may not have been created).  
            if (wc_out_err eq '') then begin

               ; Read the results of the SPLOT fit.  
               lineread = fix(strmid(wc_out,0,strpos(wc_out,' ')))
               readcol,'splot.log',skipline=lineread[0]-1,format='(F,F,F,F,F,F)',newcent,newcont,newflux,newew,newcore,newfwhm
               print,'New parameters: '
               print,'Center = ',newcent
               print,'EW = ',newew
               print,'FWHM = ',newfwhm

               ; Ask if the fit was successful.  
               newfit = ''
               repeat begin
                  read,'Did you successfully fit the line? (y or n) ',newfit
               endrep until ((newfit eq 'y') or (newfit eq 'n'))

               ; Keep the new fit parameters if fit was successful.
               if (newfit eq 'y') then begin
                  ew_keep[jj] = newew[0]
                  cent_keep[jj] = newcent[0]
                  fwhm_keep[jj] = newfwhm[0]
               endif else begin
                  ; If the fit wasn't successful, flag the spectrum
                  ; as bad.
                  sflag_keep[jj] = 1
               endelse

            endif else begin
               ; If there was no SPLOT log, the use must not
               ; have been able to fit the line, so flag the 
               ; spectrum as bad.  
               sflag_keep[jj] = 1
            endelse

         endif else begin
            ; If you didn't want to refit the spectrum, ask if you
            ; just want to set the EW to zero (this is applicable
            ; when the only H-alpha there is appears to be lost
            ; in the noise / OH lines.  
            zeroit = ''
            repeat begin
               read,'Set EW to zero? (y or n) ',zeroit
            endrep until ((zeroit eq 'y') or (zeroit eq 'n'))
            
            if (zeroit eq 'y') then begin
               ew_keep(jj) = -0.0001
               cent_keep(jj) = meancent
               fwhm_keep(jj) = 0.0001
            endif else begin
               ; Otherwise flag spectrum as bad.  
               sflag_keep(jj) = 1
            endelse 
         endelse
      endif
   endif
endfor



; FILTER OUT UNUSABLE SKIES.
good_skies = where(sflag_keep eq 0)

file_good = file_all[keep[good_skies]]
aper_good = aper_all[keep[good_skies]]
ra_good = ra_all[keep[good_skies]]
dec_good = dec_all[keep[good_skies]]
exp_good = exp_all[keep[good_skies]]
ew_good = ew_keep[good_skies]
fwhm_good = fwhm_keep[good_skies]
cent_good = cent_keep[good_skies]

; Make EWs positive for easier plotting and such.  
ew_good = -ew_good


; PRINT THE INFORMATION ABOUT THE GOOD SKIES TO A FILE.  
openw,3,goodskylist
printf,3,format='(A)','# FITS TO H-ALPHA LINES IN SKY SPECTRA'
printf,3,format='(A)','# Column 1: Multispec FITS files containing the sky spectrum'
printf,3,format='(A)','# Column 2: Aperture number of the sky spectrum'
printf,3,format='(A)','# Column 3: RA (degrees)'
printf,3,format='(A)','# Column 4: Dec (degrees)'
printf,3,format='(A)','# Column 5: Exposure time (s)'
printf,3,format='(A)','# Column 6: (-) Equivalent Width of H-alpha'
printf,3,format='(A)','# Column 7: FWHM of H-alpha'
printf,3,format='(A)','# Column 8: Center of Gaussian fit to H-alpha'
for kk=0,n_elements(good_skies)-1 do begin
   printf,3,format='(A,2x,I,2x,D15.10,2x,D15.10,2x,I,2x,F10.2,2x,F8.3,2x,F15.4)',file_good[kk],aper_good[kk],ra_good[kk],dec_good[kk],exp_good[kk],ew_good[kk],fwhm_good[kk],cent_good[kk]
endfor
close,3


return
end
