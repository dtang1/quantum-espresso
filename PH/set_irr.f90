!
! Copyright (C) 2001-2003 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!---------------------------------------------------------------------
subroutine set_irr (nat, at, bg, xq, s, invs, nsym, rtau, irt, &
     irgq, nsymq, minus_q, irotmq, u, npert, nirr, gi, gimq, iverbosity, &
     u_from_file, eigen)
!---------------------------------------------------------------------
!
!     This subroutine computes a basis for all the irreducible
!     representations of the small group of q, which are contained
!     in the representation which has as basis the displacement vectors.
!     This is achieved by building a random hermitean matrix,
!     symmetrizing it and diagonalizing the result. The eigenvectors
!     give a basis for the irreducible representations of the
!     small group of q.
!
!     Furthermore it computes:
!     1) the small group of q
!     2) the possible G vectors associated to every symmetry operation
!     3) the matrices which represent the small group of q on the
!        pattern basis.
!
!     Original routine was from C. Bungaro.
!     Revised Oct. 1995 by Andrea Dal Corso.
!     April 1997: parallel stuff added (SdG)
!
  USE io_global,  ONLY : stdout
  USE kinds, only : DP
  USE constants, ONLY: tpi
  USE random_numbers, ONLY : randy
#ifdef __PARA
  use mp, only: mp_bcast
#endif
  implicit none
!
!   first the dummy variables
!

  integer ::  nat, nsym, s (3, 3, 48), invs (48), irt (48, nat), &
       iverbosity, npert (3 * nat), irgq (48), nsymq, irotmq, nirr
! input: the number of atoms
! input: the number of symmetries
! input: the symmetry matrices
! input: the inverse of each matrix
! input: the rotated of each atom
! input: write control
! output: the dimension of each represe
! output: the small group of q
! output: the order of the small group
! output: the symmetry sending q -> -q+
! output: the number of irr. representa
! input: if rec_code > 0 u, nirr, and npert are read from the recover file 
!        and are not recalculated here

  real(DP) :: xq (3), rtau (3, 48, nat), at (3, 3), bg (3, 3), &
       gi (3, 48), gimq (3)
! input: the q point
! input: the R associated to each tau
! input: the direct lattice vectors
! input: the reciprocal lattice vectors
! output: [S(irotq)*q - q]
! output: [S(irotmq)*q + q]

  complex(DP) :: u(3*nat, 3*nat)
! output: the pattern vectors
  logical :: minus_q, u_from_file
! output: if true one symmetry send q -
! input: if true the displacement patterns are not calculated here
!
!   here the local variables
!
  integer :: na, nb, imode, jmode, ipert, jpert, nsymtot, imode0, &
       irr, ipol, jpol, isymq, irot, sna
  ! counters and auxiliary variables

  integer :: info

  real(DP) :: eigen (3 * nat), modul, arg
! the eigenvalues of dynamical matrix
! the modulus of the mode
! the argument of the phase

  complex(DP) :: wdyn (3, 3, nat, nat), phi (3 * nat, 3 * nat), &
       wrk_u (3, nat), wrk_ru (3, nat), fase
! the dynamical matrix
! the dynamical matrix with two indices
! pattern
! rotated pattern
! the phase factor

  logical :: lgamma
! if true gamma point
!
!   Allocate the necessary quantities
!
  lgamma = (xq(1) == 0.d0 .and. xq(2) == 0.d0 .and. xq(3) == 0.d0)
!
!   find the small group of q
!
  call smallgq (xq,at,bg,s,nsym,irgq,nsymq,irotmq,minus_q,gi,gimq)

  IF (.NOT. u_from_file) THEN
!
!   then we generate a random hermitean matrix
!
     arg = randy(0)
     call random_matrix (irt,irgq,nsymq,minus_q,irotmq,nat,wdyn,lgamma)
!call write_matrix('random matrix',wdyn,nat)
!
! symmetrize the random matrix with the little group of q
!
     call symdynph_gq (xq,wdyn,s,invs,rtau,irt,irgq,nsymq,nat,irotmq,minus_q)
!call write_matrix('symmetrized matrix',wdyn,nat)
!
!  Diagonalize the symmetrized random matrix.
!  Transform the symmetryzed matrix, currently in crystal coordinates,
!  in cartesian coordinates.
!
     do na = 1, nat
        do nb = 1, nat
           call trntnsc( wdyn(1,1,na,nb), at, bg, 1 )
        enddo
     enddo
!
!     We copy the dynamical matrix in a bidimensional array
!
     do na = 1, nat
        do nb = 1, nat
           do ipol = 1, 3
              imode = ipol + 3 * (na - 1)
              do jpol = 1, 3
                 jmode = jpol + 3 * (nb - 1)
                 phi (imode, jmode) = wdyn (ipol, jpol, na, nb)
              enddo
           enddo
        enddo
     enddo
!
!   Diagonalize
!
     call cdiagh (3 * nat, phi, 3 * nat, eigen, u)

!
!   We adjust the phase of each mode in such a way that the first
!   non zero element is real
!
     do imode = 1, 3 * nat
        do na = 1, 3 * nat
           modul = abs (u(na, imode) )
           if (modul.gt.1d-9) then
              fase = u (na, imode) / modul
              goto 110
           endif
        enddo
        call errore ('set_irr', 'one mode is zero', imode)
110     do na = 1, 3 * nat
           u (na, imode) = - u (na, imode) * CONJG(fase)
        enddo
     enddo
!
!  We have here a test which writes eigenvectors and eigenvalues
!
     if (iverbosity.eq.1) then
        do imode=1,3*nat
           WRITE( stdout, '(2x,"autoval = ", e10.4)') eigen(imode)
           WRITE( stdout, '(2x,"Real(aut_vet)= ( ",6f10.5,")")') &
               (  DBLE(u(na,imode)), na=1,3*nat )
           WRITE( stdout, '(2x,"Imm(aut_vet)= ( ",6f10.5,")")') &
               ( AIMAG(u(na,imode)), na=1,3*nat )
        end do
     end if
!
!  Here we count the irreducible representations and their dimensions
     do imode = 1, 3 * nat
! initialization
        npert (imode) = 0
     enddo
     nirr = 1
     npert (1) = 1
     do imode = 2, 3 * nat
        if (abs (eigen (imode) - eigen (imode-1) ) / (abs (eigen (imode) ) &
          + abs (eigen (imode-1) ) ) .lt.1.d-4) then
           npert (nirr) = npert (nirr) + 1
           if (npert (nirr) .gt. 6) call errore('set_irr', 'npert > 6 ', nirr)
        else
           nirr = nirr + 1
           npert (nirr) = 1
        endif
     enddo
  endif
!    Note: the following lines are for testing purposes
!
!      nirr = 1
!      npert(1)=1
!      do na=1,3*nat/2
!        u(na,1)=(0.d0,0.d0)
!        u(na+3*nat/2,1)=(0.d0,0.d0)
!      enddo
!      u(1,1)=(-1.d0,0.d0)
!      WRITE( stdout,'(" Setting mode for testing ")')
!      do na=1,3*nat
!         WRITE( stdout,*) u(na,1)
!      enddo
!      nsymq=1
!      minus_q=.false.

#ifdef __PARA
!
! parallel stuff: first node broadcasts everything to all nodes
!
400 continue
  call mp_bcast (gi, 0)
  call mp_bcast (gimq, 0)
  call mp_bcast (u, 0)
  call mp_bcast (nsymq, 0)
  call mp_bcast (npert, 0)
  call mp_bcast (nirr, 0)
  call mp_bcast (irotmq, 0)
  call mp_bcast (irgq, 0)
  call mp_bcast (minus_q, 0)
#endif
  return
end subroutine set_irr
