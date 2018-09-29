Open Perl IDE
Copyright © 2001 Jürgen Güntherodt, All Rights Reserved
e-mail: jguentherodt@users.sourceforge.net
--------------------------------------------------------------------------------

Contents of this readme.txt:
-Introduction
-Files
-Requirements and installation notes
-License
-Disclaimer
--------------------------------------------------------------------------------

Introduction:

Open Perl IDE is an integrated development environment, written with Delphi 5, 
for writing and debugging Perl scripts with ActiveState's ActivePerl distribution 
under Windows 95/98/NT/2000.

For the latest news visit our websites 
http://open-perl-ide.sourceforge.net or http://www.lost-sunglasses.de
--------------------------------------------------------------------------------

Files:

The following files are included:
history.txt		  	Version history
Open_Perl_IDE_ActivePerl_*.zip  Patch for working with ActivePerl 5.6.1
Open_Perl_IDE_Source_*.zip 	The source code of Open Perl IDE
Open_Perl_IDE_Tutorial.zip	A HelloWorld demo script, including a tutorial.
Open_Perl_IDE_UserManual_*.zip	The user manual in HTML format
PerlIDE.exe		  	The windows executable (Win95/98/NT/2000)
readme.txt		  	This file
--------------------------------------------------------------------------------

Requirements:

The binary PerlIDE.exe only requires a proper installed ActiveState ActivePerl 5.6. 
Of course, it is always possible to write nice perl scripts with Open Perl IDE, 
but if you want to run or debug these scripts, then you must have ActivePerl installed. 
You can download ActivePerl from http://www.activestate.com/ActivePerl/

IMPORTANT INSTALLATION NOTES:
-It is strongly recommended to install Open Perl IDE in it's own directory ! 
-The following files are created by Open Perl IDE: PerlIDE.ini, dbTemplate.txt and 
perl5db.pl.  Please do *not* change or delete any of these files, unless you 
*really* know what you do !
-If the PATH environment variable contains a path to perl.exe, then Open Perl IDE uses 
this path. You can set the path to perl.exe in the Preferences|General-Tabsheet.


Additional SourceCode Requirements:

First of all, this program is compiled with Delphi 5. It should be no problem to 
compile it with Delphi 2-4, but I haven't tried it, yet.

There are two great external packages used by Open Perl IDE:
-SynEdit components for SourceCode Editor and Perl SyntaxColoring, 
visit http://synedit.sourceforge.net
-EldoS ElTree Lite package for an enhanced TreeView, used in debug watch tree 
and other debug windows, visit http://www.eldos.org/elpack/eltree.html
--------------------------------------------------------------------------------

License:

Open Perl IDE is OpenSource under Mozilla Public License 1.1 (the "License").
You may obtain a copy of the License at http://www.mozilla.org/MPL/
--------------------------------------------------------------------------------

Disclaimer:

THE SOFTWARE IS PROVIDED UNDER THIS LICENSE ON AN "AS IS'' 
BASIS, WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR 
IMPLIED, INCLUDING, WITHOUT LIMITATION, WARRANTIES THAT THE 
SOFTWARE IS FREE OF DEFECTS, MERCHANTABLE, FIT FOR A 
PARTICULAR PURPOSE OR NON-INFRINGING. THE ENTIRE RISK AS TO 
THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. 
SHOULD THE SOFTWARE PROVE DEFECTIVE IN ANY RESPECT, YOU (NOT 
THE INITIAL DEVELOPER OR ANY OTHER CONTRIBUTOR) ASSUME THE 
COST OF ANY NECESSARY SERVICING, REPAIR OR CORRECTION. THIS 
DISCLAIMER OF WARRANTY CONSTITUTES AN ESSENTIAL PART OF 
THIS LICENSE. NO USE OF THE SOFTWARE IS AUTHORIZED HEREUNDER 
EXCEPT UNDER THIS DISCLAIMER.
--------------------------------------------------------------------------------
