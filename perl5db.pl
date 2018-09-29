# Open Perl IDE - Debugger Script - Version 0.9.8.150
#
# The contents of this file are subject to the Mozilla Public License
# Version 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at http://www.mozilla.org/MPL/

# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
# the specific language governing rights and limitations under the License.

# The Original Code is: perl5db.pl template, included in Main.pas, released 11 Mar 2001.

# The Initial Developer of the Original Code is: Jürgen Güntherodt
# (jguentherodt@users.sourceforge.net).

# Portions created by Jürgen Güntherodt are Copyright (C) 2001 Jürgen Güntherodt.
# All Rights Reserved.

# Alternatively, the contents of this file may be used under the terms of the
# GNU General Public License Version 2 or later (the "GPL"), in which case
# the provisions of the GPL are applicable instead of those above.
# If you wish to allow use of your version of this file only under the terms
# of the GPL and not to allow others to use your version of this file
# under the MPL, indicate your decision by deleting the provisions above and
# replace them with the notice and other provisions required by the GPL.
# If you do not delete the provisions above, a recipient may use your version
# of this file under either the MPL or the GPL.

# $Id$

# You may retrieve the latest version of this file at the Open Perl IDE webpage, 
# located at http://open-perl-ide.sourceforge.net or http://www.lost-sunglasses.de

package DB;

use strict;
no strict "refs";

use Cwd;
use File::Spec;
use IO::Socket::INET;


my $DM_START_REP = 65792;
my $DM_MODULE_LOADED_REP = 65793;
my $DM_STOP_REP = 66048;
my $DM_LINE_REP = 66304;
my $DM_EVAL_CODE_REP = 66816;
my $DM_CALLSTACK_REP = 67072;
my $DM_OUTPUT_REP = 67584;


my $__InternalDebugSocket;
my @__InternalSubNames;
my $__InternalCurrentFileName;
my $__InternalCurrentLine;
my $__InternalAfterLoading = 1;
my $__InternalBreakpointOnFirstLine = 0;
my %__LoadedModules;




################################################################################
## Exception handling
################################################################################
## - try
## - catch
################################################################################
sub try (&@) {
  my ($try, $catch) = @_;
  eval { &$try };
  if ($@) {
    local $_ = $@;
    &$catch;
  }
}


sub catch (&) {
  $_[0]
}



################################################################################
## Helper functions for request handling
################################################################################
## - AddBreakpoint
## - DeleteBreakpoint
## - ClearBreakpoints
## - GetCallStack
## - ShortEval
## - LongEval
## - InternalEvalCode
## - HashToStr
## - ShowDerefValues
## - ExpandFileName
################################################################################
sub AddBreakpoint {
  my ($package, $filename, $line, @condition) = @_;
  
  $filename = $__LoadedModules{$filename};
  
  my $condition = join("\t", @condition) || 1;
  local (*DB::dbline) = $main::{'_<' . $filename};
  $DB::dbline{$line} = "$condition";

  if ($__InternalAfterLoading) {
    if (($filename eq $__InternalCurrentFileName) && ($line eq $__InternalCurrentLine)) {
      $__InternalBreakpointOnFirstLine = 1;
    }
  }

  return 1;
}


sub DeleteBreakpoint {
  my ($package, $filename, $line) = @_;

  $filename = $__LoadedModules{$filename};

  local (*DB::dbline) = $main::{'_<' . $filename};
  $DB::dbline{$line} = undef;
  return 1;
}

sub ClearBreakpoints {
  my ($package, $filename) = @_;

  $filename = $__LoadedModules{$filename};

  local (*DB::dbline) = $main::{'_<' . $filename};
  foreach (keys %DB::dbline) {
    $DB::dbline{$_} = undef;
  }
  return 1;
}

sub GetCallStack {
  my ($Level) = @_;
  my $Info = $__InternalSubNames[-$Level];
  if ($Info) {
    $Level .= "\n$Info";
  }
  return "$Level";
}


sub HashToStr {
  my ($hashRef) = @_;
  my $value;
  foreach (sort keys %$hashRef) {
    $value .= "'$_' => '".$hashRef->{$_}."', ";
  }
  $value = substr($value, 0, length($value) - 2);
  return $value;
}


sub ArrayToStr {
  my ($arrayRef) = @_;
  my $value;
  for (my $i = 0; $i < @$arrayRef; $i++) {
    my $token = $arrayRef->[$i];
    if (defined $token) {
      $token = "'".$token."'";
    } else {
      $token = '<undef>';
    }
    $value .= $token.', ';
  }
  $value = substr($value, 0, length($value) - 2);
  return $value;
}


sub ShortEval {
  my ($reference) = @_;
  my $refType = ref($reference);
  if ($refType eq 'SCALAR') {
    (defined($$reference)) ? return 'scalar = '."'".$$reference."'": return 'scalar = <undef>';
  } elsif ($refType eq 'ARRAY') {
    return 'array[0..'.(scalar(@$reference) - 1)."] = (".ArrayToStr($reference).")";
  } elsif ($refType eq 'HASH') {
    return 'hash['.scalar(keys %$reference).'] = ('.HashToStr($reference).')';
  } elsif ($refType eq 'REF') {
    return '->'.ShortEval($$reference);
  } else {
    if ($refType) {
      # Interprete as class reference
      return 'class '.$refType.' = ('.HashToStr($reference).')';
    } else {
      return InternalEvalCode($$reference);
    }
  }
}


sub IntToHex {
  my ($value, $len) = @_;
  return sprintf('%0'."$len".'X', $value);
}


sub HexEncode {
  my ($value) = @_;
  return IntToHex(length($value), 8).$value;
}


sub LongEval {
  my ($reference) = @_;
  my $refType = ref($reference);
  my ($name, $value, $retValue);
  if ($refType eq 'SCALAR') {
    $retValue .= HexEncode($name).HexEncode($value);
  } elsif ($refType eq 'ARRAY') {
    for (my $i = 0; $i < @$reference; $i++){
      ($name, $value) = ("[$i]", $reference->[$i]);
      $value = ShortEval(\$value);
      $retValue .= HexEncode($name).HexEncode($value);
    }
  } elsif ($refType eq 'HASH') {
    foreach (sort keys %$reference) {
      ($name, $value) = ("{'$_'}", $reference->{$_});
      $value = ShortEval(\$value);
      $retValue .= HexEncode($name).HexEncode($value);
    }
  } elsif ($refType eq 'REF') {
      $retValue = LongEval($$reference);
  } else {
    if ($refType) {
      foreach (sort keys %$reference) {
        ($name, $value) = ("{'$_'}", $reference->{$_});
        $value = ShortEval(\$value);
        $retValue .= HexEncode($name).HexEncode($value);
      }
    } else {
       $name = $$reference;
       $value = InternalEvalCode($$reference);
       $retValue .= HexEncode($name).HexEncode($value);
    }
  }
  return $retValue;
}


sub InternalEvalCode {
  return eval shift;
}


# Takes any given reference and returns the values in human readable format
# References to objects are automatically dereferenced
sub ShowDerefValues {
  my ($reference) = @_;
  my ($type, $value);
  my $refType = ref($reference);


  if ($refType eq 'SCALAR') {
    $type = 'scalar';
    $value = $$reference;
  } elsif ($refType eq 'ARRAY') {
    $type = 'array['.scalar(@$reference).']';
    $value = '('.join(', ', @$reference).')';
  } elsif ($refType eq 'HASH') {
    $type = 'hash['.scalar(%$reference).']';
    $value = "(";
    foreach (sort keys %$reference) {
      $value .= "$_ => ".$reference->{$_}.", ";
    }
    if (length($value) > 1) {
      $value = substr($value, 0, length($value) - 2).")";
    } else {
      $value = '()';
    }
  } elsif ($refType eq 'REF') {
    return ShowDerefValues($$reference);
  } else {
    # Interprete as class reference
    $type = $refType;
    $value = "(";
    foreach (sort keys %$reference) {
      my $delta = $reference->{$_};
      $value .= "$_ => ".$delta.", ";
    }
    if (length($value) > 1) {
      $value = substr($value, 0, length($value) - 2).")";
    } else {
      $value = '()';
    }
  }

  return $type.' = '.$value;
}


sub ExpandFileName {
  my $filename = shift;
  if ($filename =~ m/^\(/) {
    return $filename;
  } else {
    my ($volume, $directories, $file) = File::Spec->splitpath($filename);
    return Cwd::abs_path($volume.$directories).'/'.$file;
  }
}





################################################################################
## Communication control
################################################################################
## - SendReport
## - ReceiveRequest
## - HandleRequest
################################################################################
sub SendReport {
  my ($sock, $report, $data) = @_;

  if (!$sock) {
     return;
  }

  if ($data) {
    $report .= "\n$data";
  }

  my $length = length($report);
  my $PackedLength = pack('L', $length);

  $sock->send($PackedLength);
  $sock->send($report);
}


sub ReceiveRequest {
  my ($sock) = @_;

  if (!$sock) {
    return;
  }

  my ($b1, $b2, $b3, $b4);
  $sock->recv($b1, 1);
  $sock->recv($b2, 1);
  $sock->recv($b3, 1);
  $sock->recv($b4, 1);

  my $RequestLength = unpack('L', $b1.$b2.$b3.$b4);

  my $data;
  my $i = 0;
  my $s;

  while ($i < $RequestLength) {
    $sock->recv($s, $RequestLength - $i);
    $data .= $s;
    $i = length($data);
  }

  return $data;
}


sub HandleRequest {
  my ($sock, $package) = @_;

  my $request = ReceiveRequest($sock);

  my $value = '-1';

  if ($request eq "STOP") {
    SendReport($sock, $DM_STOP_REP);
    $__InternalDebugSocket = 0;
#    print "\n\n>>> Debug session aborted";
#    die "> Debug session terminated";
    print "> Debug session terminated";
    exit;
  } elsif ($request eq "RUN") {
    $DB::single = 0;
    if ($__InternalBreakpointOnFirstLine && $__InternalAfterLoading) {
      $value = 1;
      $__InternalBreakpointOnFirstLine = 0;
      $__InternalCurrentFileName = ExpandFileName($__InternalCurrentFileName);
      SendReport($__InternalDebugSocket, $DM_LINE_REP, "$__InternalCurrentFileName\n$__InternalCurrentLine\n");
    }
  } elsif ($request eq "STEP_OVER") {
    $DB::single = 2;
  } elsif ($request eq "STEP_INTO") {
    $DB::single = 1;
  } elsif ($request eq "STEP_OUT") {
    print STDERR "DM_STEP_OUT_REQ currently not supported\n";
  } elsif ($request =~ m/^EVAL_CODE=(.*?)<(.*)/io) {
    my ($requestID, $evalcode) = ($1, $2);
    $value = InternalEvalCode($evalcode);
    SendReport($sock, $DM_EVAL_CODE_REP, "$requestID\n$evalcode\n$value");
    $value = 1;
  } elsif ($request =~ m/^CLEAR_BREAKPOINTS=<(.*)/io) {
    $value = ClearBreakpoints($package, $1);
  } elsif ($request =~ m/^ADD_BREAKPOINT=<(.*)/io) {
    $value = AddBreakpoint($package, split(/\t/, $1));
  } elsif ($request =~ m/^DELETE_BREAKPOINT=<(.*)/io) {
    $value = DeleteBreakpoint($package, split(/\t/, $1));
  } elsif ($request =~ m/^CALLSTACK=(.*)/io) {
    $value = GetCallStack($1);
    SendReport($sock, $DM_CALLSTACK_REP, $value);
  } else {
#    print "Unknown request: $request\n";
  }

  return $value;
}


################################################################################
## Magic perl debug functions (package DB)
################################################################################
## - DB
## - sub
## - postponed
################################################################################
my @__InternalDebugStack;
my $initialized;

sub DB {
  my ($package, $filename, $lineno) = caller;
  
  $__InternalCurrentFileName = $filename;
  $__InternalCurrentLine = $lineno;

  if ($__InternalAfterLoading) {
    SendReport($__InternalDebugSocket, $DM_START_REP);
  }

  # if and only if $DB::single == 0 then we've reached a breakpoint
  # Now we check the corresponding condition
  if (!($DB::single)) {
    local (*DB::dbline) = $main::{'_<' . $filename};
    my $condition = $DB::dbline{$lineno};
    my $value = InternalEvalCode("return $package::$condition;");
    if (!$value) {
      return;
    }
  }

  $filename = ExpandFileName($filename);
  SendReport($__InternalDebugSocket, $DM_LINE_REP, "$filename\n$lineno\n");

  my $response = HandleRequest($__InternalDebugSocket, $package);
  while ($response ne '-1') {
    $response = HandleRequest($__InternalDebugSocket, $package);
  }
  
  $__InternalAfterLoading = 0;
}


sub sub {

  if ($initialized) {

    push(@__InternalDebugStack, $DB::single);
    my @OldStack = @__InternalDebugStack;

    if ($DB::single == 2) {
      $DB::single = 0;
    }

    my $SubInfo = $DB::sub;

#    if (($SubInfo =~ m/^CODE.*/io) || ($SubInfo =~ m/AUTOLOAD$/io)
#    || ($SubInfo =~ m/^Win32::OLE.*/io)
#    || ($SubInfo =~ m/^Carp::.*/io)) {
#    } else {
#      $SubInfo .= '('.join(', ', @_).')';
#    }
    my @test = @_;
    try {
      $SubInfo .= '('.join(', ', @test).')';
    } catch {
      $SubInfo .= "($@)";
    };

    push(@__InternalSubNames, $SubInfo);
    my @OldSubNames = @__InternalSubNames;

    my $returnValue;
    my @returnValue;

    if (defined wantarray) {
      if (wantarray) {
        @returnValue = &$DB::sub;
      } else {
        $returnValue = &$DB::sub;
      }
    } else {
      &$DB::sub;
    }
    pop(@__InternalSubNames);

    if (@__InternalDebugStack != @OldStack) {
      @__InternalDebugStack = @OldStack;
      @__InternalSubNames = @OldSubNames;
    }

    if (pop(@__InternalDebugStack) == 2) {
      $DB::single = 2;
    }

    if (defined wantarray) {
      if (wantarray) {
        return @returnValue;
      } else {
        return $returnValue;
      }
    } else {
      return;
    }

  } else {
    return &$DB::sub;
  }
}


sub postponed {
  my ($filename) = @_;
  if ($filename =~ m/^\*main::_<(.*)/i) {
    my $LoadedModuleName = $1;
    my $xfn = ExpandFileName($LoadedModuleName);
    SendReport($__InternalDebugSocket, '65793', $xfn);
    my @parts = split(/\//, $xfn);
    my $sfn = $parts[-1];
    $__LoadedModules{$sfn} = $LoadedModuleName;
  }
  return 1;
}

################################################################################
## Initialization and finalization
################################################################################
## - BEGIN
## - END
################################################################################
BEGIN {
  print "Entering open perl debugger, connecting to port 53723...";
  $__InternalDebugSocket = IO::Socket::INET->new( PeerAddr => '127.0.0.1',
                                 PeerPort => 53723,
                                 Proto => 'tcp');
  while (!$__InternalDebugSocket) {
    print "\nconnection to port 53723 failed - try again...";
    $__InternalDebugSocket = IO::Socket::INET->new( PeerAddr => '127.0.0.1',
                                   PeerPort => 53723,
                                   Proto => 'tcp');
  }

  print "connected.\n\n";

  $DB::single = 0;
  $initialized = 1;

  # Unbuffered STDOUT and STDERR
  $| = 1;
  autoflush STDERR 1;
}


END {
  $DB::single = 0;
  if ($__InternalDebugSocket) {
    SendReport($__InternalDebugSocket, $DM_STOP_REP);
    print "\n>Program terminated.\n";
  }
}

1;
