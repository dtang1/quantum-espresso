!
!--------------------------------------------------------------------------
      subroutine descreening
!--------------------------------------------------------------------------
!
!     This routine descreens the local potential and the ddd
!     coefficients (the latter only in the US case)
!     The charge density is computed with the test configuration,
!     not the one used to generate the pseudopotential
!      
use ld1inc
implicit none


integer ::    &
        ns,  &     ! counter on pseudo functions
        ns1, &    ! counter on pseudo functions
        ib,jb, &  ! counter on beta functions
        lam      ! the angualar momentum

real(kind=dp) :: &
        xc(8),  &    ! parameters of bessel functions
        gi(ndm,2), & ! auxiliary to compute the integrals
        phist(ndm,nwfsx), & !save the phi
        sum,       & ! the integral
        int_0_inf_dr ! the integral function
     
real(kind=dp), parameter :: &
               thresh= 1.d-12          ! the selfconsisten limit

integer  :: &
        m, n, l, n1, n2, nwf0, nst, ikl, imax, iwork(nwfsx), &
        is, nbf, nc, ios
!
!     descreening the local potential: NB: this descreening is done with
!     the occupation of the test configuration. This is required
!     for pseudopotentials with semicore states. In the other cases
!     a test configuration equal to the one used for pseudopotential
!     generation is strongly suggested
!
nc=1
nwfts=nwftsc(nc)
do n=1,nwfts
   nnts(n)=nntsc(n,nc)
   llts(n)=lltsc(n,nc)
   elts(n)=eltsc(n,nc)
!         rcutts(n)=rcut(n)
!         rcutusts(n)=rcutus(n)
   jjts(n) = jjtsc(n,nc)
   iswts(n)=iswtsc(n,nc)
   octs(n)=octsc(n,nc)
   nstoae(n)=nstoaec(n,nc)
   enls(n)=enl(nstoae(n))
   new(n)=.false.
enddo

do ns=1,nwfts
   do n=1,mesh
      phis(n,ns)=phist(n,ns)
   enddo
enddo
!
!    compute the pseudowavefunction in the test configuration
!
if (pseudotype.eq.1) then
   nbf=0
else
   nbf=nbeta
endif

do ns=1,nwfts
   if (octs(ns).gt.0.d0) then
      is=iswts(ns)
      if (pseudotype.eq.1) then
         do n=1,mesh
            vpsloc(n)=vpsloc(n)+vnl(n,llts(ns))
         enddo
      endif
      call ascheqps(nnts(ns),llts(ns),jjts(ns),enls(ns),    &
             mesh,ndm,dx,r,r2,sqr,vpsloc,thresh,phis(1,ns), & 
             betas,bmat,qq,nbf,nwfsx,lls,jjs,ikk)
!            write(6,*) ns, nnts(ns),llts(ns), jjts(ns), enls(ns)
      if (pseudotype.eq.1) then
         do n=1,mesh
            vpsloc(n)=vpsloc(n)-vnl(n,llts(ns))
         enddo
      endif
   endif
enddo
!
!    descreening the D coefficients
!
if (pseudotype.eq.3) then
   do ib=1,nbeta
      do jb=1,ib
         if (lls(ib).eq.lls(jb).and.abs(jjs(ib)-jjs(jb)).lt.1.d-7) then
            lam=lls(ns)
            nst=(lam+1)*2
            do n=1,ikk(ib)
               gi(n,1)=qvan(n,ib,jb)*vpsloc(n)
            enddo
            bmat(ib,jb)= bmat(ib,jb)  &
                     - int_0_inf_dr(gi,r,r2,dx,ikk(ib),nst)
         endif
         bmat(jb,ib)=bmat(ib,jb)
      enddo
   enddo
   write(6,'(/5x,'' The ddd matrix'')')
   do ns1=1,nbeta
      write(6,'(6f12.5)') (bmat(ns1,ns),ns=1,nbeta)
   enddo
endif
!
!    descreening the local pseudopotential
!
iwork=1
call normalize
call chargeps(nwfts,llts,jjts,octs,iwork)

call new_potential(ndm,mesh,r,r2,sqr,dx,0.d0,vxt,lsd,nlcc,latt,enne, &
                   rhoc,rhos,vh,gi)

do n=1,mesh
   vpstot(n,1)=vpsloc(n)
   vpsloc(n)=vpsloc(n)-gi(n,1)
enddo
       
if (file_screen .ne.' ') then
    open(unit=20,file=file_screen, status='unknown', iostat=ios, &
                   err=100 )
100       call errore('descreening','opening file'//file_screen,abs(ios))
   do n=1,mesh
       write(20,'(i5,7e12.4)') n,r(n), vpsloc(n)+gi(n,1), vpsloc(n), &
                 gi(n,1),   rhos(n,1)
   enddo
   close(20)
endif 
!
!  copy the phis used to construct the pseudopotential
!
do ns=1,nwfts
   do n=1,mesh
      phis(n,ns)=phist(n,ns)
   enddo
enddo

return
end
