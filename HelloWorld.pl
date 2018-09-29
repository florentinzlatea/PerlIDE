# Open Perl IDE Demo Script

# Welcome to Open Perl IDE
# This demo script should give you a short tutorial of how to use Open Perl IDE.
# You can find a more detailed description of this program in the User Manual.

# First of all, here are some words to the SyntaxColoring:
# Per default, comments are green, strings are red, numbers are blue and all
# other text is black colored. Comments are written italic and keywords are bold.
#
# To change the settings for SyntaxColoring, open the Edit | Preferences
# dialog and switch to the editor page.

# Now we try to invoke the Perl interpreter perl.exe, which must have been
# to compile, debug or run perl scripts.
# If the IDE does not find perl.exe, it will ask you to enter an appropriate
# directory. You can set this path manually on the General page of the
# Edit | Preferences dialog.

# Press Ctrl-F9 or select Compile from the Run menu to compile the script.
# Then a short message should appear in the Console window, saying that the
# open perl debugger has been connected to a port and that the debug session
# has been terminated.
# This is the normal output of a compile action, if the script contains no
# syntax errors. If there are syntax errors, then there is no termination
# message and the erroneous lines are in the Error Output window.
#
# Important: Please don't forget to save your script before compiling it.

# The next step is to debug the script. Press F8 or select Step Over from the
# Run menu... and regard the first executed line of the script, line 46.
# In debug mode, press F8 to step to next line, press F7 to trace into
# a function, press F9 to continue execution until the next breakpoint is reached.
# At any time, you can press Ctrl-F2 to request an abortion of the debug session
# or open the taskmanager and shutdown perl.exe to immediately terminate the
# debug session.
use strict;
use warnings;

sub Multiply {
  my ($f1, $f2) = @_;
  return $f1 * $f2;
}

# The next line is the first executed line of this script, press F8 to go on.
print "Let's test Open Perl IDE...\n";

# You can enter start parameter in the edit field on the top of the Console Tab.
# The array @ARGV contains all start parameter, move the mouse over @ARGV to
# view the parameter.
print join(',', @ARGV)."\n";

my $i = Multiply(3, 4);
# The value of $i should be 12. Check this be moving the mouse over $i or
# drag&drop $i to the Variables window.

# Here we construct a nested data structure ...
my @testarray = ("alpha", "beta", "gamma");
$testarray[3] = \@testarray;
# ...,@testarray now contains a reference to itself at position 3.
# Select @testarray and drag&drop it to the Variables window. The contents are
# immediately shown in a watch tree.

# Use the following loop to test breakpoints, debug navigation and the CallStack.
# For example, set a breakpoint on line 69 by clicking on the line number.
# Remove the breakpoint by clicking again on the line number.
# Make some experiments with F8 and F7 on line 69 and watch the CallStack window.
for (my $j = 0; $j < 8; $j++) {
  $i = Multiply($i, $i);
  print "$j: $i\n";
}

# Finally, here is a test of STDIN / STDOUT redirection from / to Console window.

$| = 1; # Force unbuffered STDOUT and STDIN.
print "Begin of the STDIN endless loop. Enter a line in the Console window and press Return.\n";
print "The normal way to leave this endless loop is pressing Ctrl-Z.\n";
print "To immediately abort any debug/run session, open the taskmanager and shutdown perl.exe.\n";
while (my $Line = <STDIN>) {
  chomp($Line);
  print $Line*$Line."\n";
}


print "Open Perl IDE Test finished.\n"

