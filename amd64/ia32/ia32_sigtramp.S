/*-
 * Copyright (c) 2003 Peter Wemm
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * $FreeBSD: releng/10.3/sys/amd64/ia32/ia32_sigtramp.S 276601 2015-01-03 01:41:10Z kib $
 */

#include "opt_compat.h"

#include <machine/asmacros.h>
#include <sys/syscall.h>

#include "ia32_assym.h"

	.text
	.code32
/*
 * Signal trampoline, copied to top of user stack
 * XXX may need to be MD to match backend sendsig handoff protocol
 */
	ALIGN_TEXT
	.globl	ia32_sigcode
ia32_sigcode:
	calll	*IA32_SIGF_HANDLER(%esp)
	leal	IA32_SIGF_UC(%esp),%eax	/* get ucontext */
	pushl	%eax
	movl	$SYS_sigreturn,%eax
	pushl	%eax			/* junk to fake return addr. */
	int	$0x80			/* enter kernel with args */
					/* on stack */
1:
	jmp	1b

#ifdef COMPAT_FREEBSD4
	ALIGN_TEXT
freebsd4_ia32_sigcode:
	calll	*IA32_SIGF_HANDLER(%esp)
	leal	IA32_SIGF_UC4(%esp),%eax/* get ucontext */
	pushl	%eax
	movl	$344,%eax		/* 4.x SYS_sigreturn */
	pushl	%eax			/* junk to fake return addr. */
	int	$0x80			/* enter kernel with args */
					/* on stack */
1:
	jmp	1b
#endif

#ifdef COMPAT_43
	ALIGN_TEXT
ia32_osigcode:
	calll	*IA32_SIGF_HANDLER(%esp)/* call signal handler */
	leal	IA32_SIGF_SC(%esp),%eax	/* get sigcontext */
	pushl	%eax
	movl	$103,%eax		/* 3.x SYS_sigreturn */
	pushl	%eax			/* junk to fake return addr. */
	int	$0x80			/* enter kernel with args */
1:
	jmp	1b


/*
 * The lcall $7,$0 emulator cannot use the call gate that does an
 * inter-privilege transition. The reason is that the call gate
 * does not disable interrupts, and, before the swapgs is
 * executed, we would have a window where the ring 0 code is
 * executed with the wrong gsbase.
 *
 * Instead, set LDT descriptor 0 as code segment, which reflects
 * the lcall $7,$0 back to ring 3 trampoline.  The trampoline sets up
 * the frame for int $0x80.
 */
	ALIGN_TEXT
lcall_tramp:
	cmpl	$SYS_vfork,%eax
	je	1f
	pushl	%ebp
	movl	%esp,%ebp
	pushl	0x24(%ebp) /* arg 6 */
	pushl	0x20(%ebp)
	pushl	0x1c(%ebp)
	pushl	0x18(%ebp)
	pushl	0x14(%ebp)
	pushl	0x10(%ebp) /* arg 1 */
	subl	$4,%esp   /* gap */
	int	$0x80
	leavel
	lretl
1:
	/*
	 * vfork handling is special and relies on the libc stub saving
	 * the return ip in %ecx.  Also, we assume that the call was done
	 * with ucode32 selector in %cs.
	 */
	int	$0x80
	movl	$0x33,4(%esp)	/* GUCODE32_SEL | SEL_UPL */
	movl	%ecx,(%esp)
	lretl
#endif

	ALIGN_TEXT
esigcode:

	.data
	.globl	sz_ia32_sigcode
sz_ia32_sigcode:
	.long	esigcode-ia32_sigcode
#ifdef COMPAT_FREEBSD4
	.globl	sz_freebsd4_ia32_sigcode
sz_freebsd4_ia32_sigcode:
	.long	esigcode-freebsd4_ia32_sigcode
#endif
#ifdef COMPAT_43
	.globl	sz_ia32_osigcode
sz_ia32_osigcode:
	.long	esigcode-ia32_osigcode
	.globl	sz_lcall_tramp
sz_lcall_tramp:
	.long	esigcode-lcall_tramp
#endif
