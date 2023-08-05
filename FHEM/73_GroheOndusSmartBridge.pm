###############################################################################
#
# Developed with eclipse on windows os using fiddler to catch ip communication.
#
#  (c) 2019 Copyright: J.K. (J0EK3R at gmx dot net)
#  All rights reserved
#
#  Special thanks goes to committers:
#  * me
#
#  This script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  The GNU General Public License can be found at
#  http://www.gnu.org/copyleft/gpl.html.
#  A copy is found in the textfile GPL.txt and important notices to the license
#  from the author is found in LICENSE.txt distributed with these scripts.
#
#  This script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#
# $Id: 73_GroheOndusSmartBridge.pm 201 2020-04-04 06:14:00Z J0EK3R $
#
###############################################################################

package main;

my $VERSION = "3.1.5";

use strict;
use warnings;

my $missingModul = "";

use FHEM::Meta;
eval {use HTML::Entities;1 or $missingModul .= "HTML::Entities "};
eval {use JSON;1 or $missingModul .= "JSON "};

#use HttpUtils;

#########################
# Forward declaration
sub GroheOndusSmartBridge_Initialize($);
sub GroheOndusSmartBridge_Define($$);
sub GroheOndusSmartBridge_Ready($);
sub GroheOndusSmartBridge_Undef($$);
sub GroheOndusSmartBridge_Delete($$);
sub GroheOndusSmartBridge_Rename(@);
sub GroheOndusSmartBridge_Attr(@);
sub GroheOndusSmartBridge_Notify($$);
sub GroheOndusSmartBridge_Set($@);
sub GroheOndusSmartBridge_Write($$);

sub GroheOndusSmartBridge_TimerExecute($);
sub GroheOndusSmartBridge_TimerRemove($);
sub GroheOndusSmartBridge_UpdateInternals($);
sub GroheOndusSmartBridge_Connect($;$$);
sub GroheOndusSmartBridge_ClearLogin($);
sub GroheOndusSmartBridge_Login($;$$);
sub GroheOndusSmartBridge_Login_GetLoginAddress($;$$);
sub GroheOndusSmartBridge_Login_PostAddress($;$$);
sub GroheOndusSmartBridge_Login_GetToken($;$$);
sub GroheOndusSmartBridge_Login_Refresh($;$$);
sub GroheOndusSmartBridge_GetDevices($;$$);
sub GroheOndusSmartBridge_GetLocations($;$$);
sub GroheOndusSmartBridge_GetRooms($$;$$);
sub GroheOndusSmartBridge_GetAppliances($$$;$$);

sub GroheOndusSmartBridge_RequestParam($$);
sub GroheOndusSmartBridge_SendReceive($$);
sub GroheOndusSmartBridge_RequestErrorHandling($$$);

sub GroheOndusSmartBridge_StorePassword($$);
sub GroheOndusSmartBridge_ReadPassword($);
sub GroheOndusSmartBridge_DeletePassword($);

sub GroheOndusSmartBridge_ProcessSetCookies($@);
sub GroheOndusSmartBridge_Header_AddAuthorization($$);
sub GroheOndusSmartBridge_Header_AddCookies($$);


my $DefaultRetries    = 3;                                                      # default number of retries
my $DefaultInterval   = 60;                                                     # default value for the polling interval in seconds
my $DefaultTimeout    = 5;                                                      # default value for response timeout in seconds

my $DefaultURL        = "https://idp2-apigw.cloud.grohe.com/v3";                # default URL
my $LoginURL          = "https://idp2-apigw.cloud.grohe.com/v3/iot/oidc/login";

my $TimeStampFormat   = "%Y-%m-%dT%H:%M:%S";

my $ReloginOffset_s   = -60;                                                    # (negative) timespan in seconds to add "expires_in" timespan to relogin

#####################################
# GroheOndusSmartBridge_Initialize( $hash )
sub GroheOndusSmartBridge_Initialize($)
{
  my ( $hash ) = @_;

  $hash->{DefFn}    = \&GroheOndusSmartBridge_Define;
  $hash->{UndefFn}  = \&GroheOndusSmartBridge_Undef;
  $hash->{DeleteFn} = \&GroheOndusSmartBridge_Delete;
  $hash->{RenameFn} = \&GroheOndusSmartBridge_Rename;
  $hash->{AttrFn}   = \&GroheOndusSmartBridge_Attr;
  $hash->{NotifyFn} = \&GroheOndusSmartBridge_Notify;
  $hash->{SetFn}    = \&GroheOndusSmartBridge_Set;
  $hash->{WriteFn}  = \&GroheOndusSmartBridge_Write;

  $hash->{Clients}   = "GroheOndusSmartDevice";
  $hash->{MatchList} = { "1:GroheOndusSmartDevice" => "GROHEONDUSSMARTDEVICE_.*" };

  $hash->{AttrList} = 
    "debugJSON:0,1 " . 
    "debug:0,1 " . 
    "autocreatedevices:1,0 " . 
    "disable:0,1 " . 
    "interval " . 
    "groheOndusAccountEmail " . 
    $readingFnAttributes;

  foreach my $d ( sort keys %{ $modules{GroheOndusSmartBridge}{defptr} } )
  {
    my $hash = $modules{GroheOndusSmartBridge}{defptr}{$d};
    $hash->{VERSION} = $VERSION;
  }

  return FHEM::Meta::InitMod( __FILE__, $hash );
}

#####################################
# GroheOndusSmartBridge_Define( $hash, $def )
sub GroheOndusSmartBridge_Define($$)
{
  my ( $hash, $def ) = @_;

  my @a = split( "[ \t][ \t]*", $def );

  return $@
    unless ( FHEM::Meta::SetInternals($hash) );

  return "too few parameters: define <NAME> GroheOndusSmartBridge"
    if ( @a != 2 );

  return "Cannot define GroheOndusBridge. Perl modul " . ${missingModul} . " is missing."
    if ($missingModul);

  my $name = $a[0];
  $hash->{VERSION}                       = $VERSION;
  $hash->{NOTIFYDEV}                     = "global,$name";
  $hash->{URL}                           = $DefaultURL;
  $hash->{INTERVAL}                      = $DefaultInterval;
  $hash->{TIMEOUT}                       = $DefaultTimeout;
  $hash->{RETRIES}                       = $DefaultRetries;
  $hash->{REQUESTID}                     = 0;

  $hash->{helper}{RESPONSECOUNT_ERROR}   = 0;
  $hash->{helper}{RESPONSESUCCESSCOUNT}  = 0; # statistics
  $hash->{helper}{RESPONSEERRORCOUNT}    = 0; # statistics
  $hash->{helper}{RESPONSETOTALTIMESPAN} = 0; # statistics
  $hash->{helper}{access_token}          = "none";
  $hash->{helper}{LoginInProgress}       = "0";
  $hash->{helper}{LoginCounter}          = 0;
  $hash->{helper}{LoginErrCounter}       = 0;
  $hash->{helper}{DEBUG}                 = "0";
  $hash->{helper}{IsDisabled}            = "0";
  $hash->{helper}{AUTOCREATEDEVICES}     = "1";
  
  # set default Attributes
  CommandAttr( undef, $name . " room GroheOndusSmart" )
    if ( AttrVal( $name, "room", "none" ) eq "none" );

  readingsSingleUpdate( $hash, "state", "initialized", 1 );

  Log3($name, 3, "GroheOndusSmartBridge_Define($name) - defined GroheOndusSmartBridge");

  $modules{GroheOndusSmartBridge}{defptr}{BRIDGE} = $hash;

  return undef;
}

####################################
# GroheOndusSmartBridge_Ready( $hash )
sub GroheOndusSmartBridge_Ready($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_Ready($name)");
}

#####################################
# GroheOndusSmartBridge_Undef( $hash, $name )
sub GroheOndusSmartBridge_Undef($$)
{
  my ( $hash, $name ) = @_;

  GroheOndusSmartBridge_TimerRemove($hash);

  delete $modules{GroheOndusSmartBridge}{defptr}{BRIDGE}
    if ( defined( $modules{GroheOndusSmartBridge}{defptr}{BRIDGE} ) );

  return undef;
}

#####################################
# GroheOndusSmartBridge_Delete( $hash, $name )
sub GroheOndusSmartBridge_Delete($$)
{
  my ( $hash, $name ) = @_;

  setKeyValue( $hash->{TYPE} . "_" . $name . "_passwd", undef );
  return undef;
}

#####################################
# GroheOndusSmartBridge_Rename( $new, $old )
sub GroheOndusSmartBridge_Rename(@)
{
  my ( $new, $old ) = @_;
  my $hash = $defs{$new};

  GroheOndusSmartBridge_StorePassword( $hash, GroheOndusSmartBridge_ReadPassword($hash) );
  setKeyValue( $hash->{TYPE} . "_" . $old . "_passwd", undef );

  return undef;
}


#####################################
# GroheOndusSmartBridge_Attr($cmd, $name, $attrName, $attrVal)
sub GroheOndusSmartBridge_Attr(@)
{
  my ( $cmd, $name, $attrName, $attrVal ) = @_;
  my $hash = $defs{$name};

  Log3($name, 4, "GroheOndusSmartBridge_Attr($name) - AttrName \"$attrName\" : \"$attrVal\"");

  # Attribute "disable"
  if ( $attrName eq "disable" )
  {
    if ( $cmd eq "set" and 
      $attrVal eq "1" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - disabled");

      $hash->{helper}{IsDisabled} = "1";
      
      GroheOndusSmartBridge_TimerRemove($hash);

      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "inactive", 1 );
      readingsEndUpdate( $hash, 1 );
    } 
    else
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - enabled");

      $hash->{helper}{IsDisabled} = "0";

      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "active", 1 );
      readingsEndUpdate( $hash, 1 );
      
      GroheOndusSmartBridge_TimerExecute($hash);      
    }
  }

  # Attribute "interval"
  elsif ( $attrName eq "interval" )
  {
    if ( $cmd eq "set" )
    {
      return "Interval must be greater than 0"
        unless ( $attrVal > 0 );

      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - set interval: $attrVal");

      GroheOndusSmartBridge_TimerRemove($hash);

      $hash->{INTERVAL} = $attrVal;

      GroheOndusSmartBridge_TimerExecute($hash);      
    } 
    elsif ( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - delete User interval and set default: $DefaultInterval");

      GroheOndusSmartBridge_TimerRemove($hash);
    
      $hash->{INTERVAL} = $DefaultInterval;

      GroheOndusSmartBridge_TimerExecute($hash);      
    }
  }

  # Attribute "debug"
  elsif ( $attrName eq "debug" )
  {
    if ( $cmd eq "set")
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - debugging enabled");

      $hash->{helper}{DEBUG} = "$attrVal";
      GroheOndusSmartBridge_UpdateInternals($hash);
    } 
    elsif ( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - debugging disabled");

      $hash->{helper}{DEBUG} = "0";
      GroheOndusSmartBridge_UpdateInternals($hash);
    }
  }

  # Attribute "groheOndusAccountEmail"
  elsif ( $attrName eq "groheOndusAccountEmail" )
  {
    if ( $cmd eq "set")
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - AccountEmail set to \"$attrVal\"");

      GroheOndusSmartBridge_TimerExecute($hash);      
    } 
    elsif ( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - AccountEmail deleted");

      GroheOndusSmartBridge_TimerRemove($hash);
    }
  }

  ### Attribute "autocreatedevices"
  elsif ( $attrName eq "autocreatedevices" )
  {
    if ( $cmd eq "set" )
    {
      if ($attrVal eq "1" )
      {
        $hash->{helper}{AUTOCREATEDEVICES} = "1";
        Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - autocreatedevices enabled");
      }
      elsif ($attrVal eq "0" )
      {
        $hash->{helper}{AUTOCREATEDEVICES} = "0";
        Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - autocreatedevices disabled");
      }
      else
      {
        return "autocreatedevices must be 0 or 1";
      }
    } 
    elsif ( $cmd eq "del" )
    {
      $hash->{helper}{AUTOCREATEDEVICES} = "1";
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - autocreatedevices disabled");
    }
  }

  return undef;
}

#####################################
# GroheOndusSmartBridge_Notify( $hash, $dev )
sub GroheOndusSmartBridge_Notify($$)
{
  my ( $hash, $dev ) = @_;
  my $name = $hash->{NAME};

  return
    if ($hash->{helper}{IsDisabled} ne "0");

  my $devname = $dev->{NAME};
  my $devtype = $dev->{TYPE};
  my $events  = deviceEvents( $dev, 1 );

  return
    if (!$events);

  Log3($name, 4, "GroheOndusSmartBridge_Notify($name) - DevType: \"$devtype\"");

  # process "global" events
  if ( $devtype eq "Global")
  { 
    if (grep(m/^INITIALIZED$/, @{$events}))
    {
      # this is the initial call after fhem has startet
      Log3($name, 3, "GroheOndusSmartBridge_Notify($name) - INITIALIZED");

      GroheOndusSmartBridge_Ready($hash);
      GroheOndusSmartBridge_TimerExecute($hash);
    }

    elsif (grep(m/^REREADCFG$/, @{$events}))
    {
      Log3($name, 3, "GroheOndusSmartBridge_Notify($name) - REREADCFG");

      GroheOndusSmartBridge_TimerExecute($hash);
    }

    elsif (grep(m/^DEFINED.$name$/, @{$events}) )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Notify($name) - DEFINED");

      GroheOndusSmartBridge_TimerExecute($hash);
    }

    elsif (grep(m/^MODIFIED.$name$/, @{$events}))
    {
      Log3($name, 3, "GroheOndusSmartBridge_Notify($name) - MODIFIED");

      GroheOndusSmartBridge_TimerExecute($hash);
    }

    if ($init_done)
    {
    }
  }
  
  # process internal events
  elsif ($devtype eq "GroheOndusSmartBridge") 
  {
  }
  
  return;
}

#####################################
# GroheOndusSmartBridge_Set( $hash, $name, $cmd, @args )
sub GroheOndusSmartBridge_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  Log3($name, 4, "GroheOndusSmartBridge_Set($name) - Set was called cmd: >>$cmd<<");

  ### Command "update"
  if ( lc $cmd eq lc "update" )
  {
    GroheOndusSmartBridge_GetDevices($hash);
  }
  ###  Command "groheOndusAccountPassword"
  elsif ( lc $cmd eq lc "groheOndusAccountPassword" )
  {
    return "please set Attribut groheOndusAccountEmail first"
      if ( AttrVal( $name, "groheOndusAccountEmail", "none" ) eq "none" );

    return "usage: $cmd <password>"
      if ( @args != 1 );

    my $passwd = join( " ", @args );
    GroheOndusSmartBridge_StorePassword( $hash, $passwd );
    GroheOndusSmartBridge_ClearLogin($hash);
    GroheOndusSmartBridge_GetDevices($hash);
  } 
  ### Command "deleteAccountPassword"
  elsif ( lc $cmd eq lc "deleteAccountPassword" )
  {
    GroheOndusSmartBridge_DeletePassword($hash);
    GroheOndusSmartBridge_ClearLogin($hash);
  } 
  ### Command "clearreadings"
  elsif ( lc $cmd eq lc "clearreadings" )
  {
    fhem("deletereading $name .*", 1);
  }
  ### Command "debugGetDevicesState"
  elsif ( lc $cmd eq lc "debugGetDevicesState" )
  {
    GroheOndusSmartBridge_GetDevices($hash);
  }
  ### Command "debugLogin"
  elsif ( lc $cmd eq lc "debugLogin" )
  {
    return "please set Attribut groheOndusAccountEmail first"
      if ( AttrVal( $name, "groheOndusAccountEmail", "none" ) eq "none" );

    return "please set groheOndusAccountPassword first"
      if ( not defined( GroheOndusSmartBridge_ReadPassword($hash) ) );

    GroheOndusSmartBridge_Login($hash);
  }
  ### Command "debugSetLoginState"
  elsif ( lc $cmd eq lc "debugSetLoginState" )
  {
    $hash->{helper}{LoginInProgress} = join( " ", @args );
    GroheOndusSmartBridge_UpdateInternals($hash);
  }
  ### Command "debugSetTokenExpired"
  elsif ( lc $cmd eq lc "debugSetTokenExpired" )
  {
    my $loginNextTimeStamp = gettimeofday();
    $hash->{helper}{LoginNextTimeStamp} = $loginNextTimeStamp; 
    GroheOndusSmartBridge_UpdateInternals($hash);
  }
  else
  {
    my $isPasswordSet = defined( GroheOndusSmartBridge_ReadPassword($hash) );
    my $list = "";

    $list .= "update:noArg "
      if ( $isPasswordSet );

    $list .= "groheOndusAccountPassword ";

    $list .= "deleteAccountPassword:noArg "
      if ( $isPasswordSet );

    $list .= "clearreadings:noArg ";

    $list .= "debugGetDevicesState:noArg "
      if ( $isPasswordSet and $hash->{helper}{DEBUG} ne "0");

    $list .= "debugLogin:noArg "
      if ( $isPasswordSet and $hash->{helper}{DEBUG} ne "0");

    $list .= "debugSetLoginState:0,1 "
      if ( $isPasswordSet and $hash->{helper}{DEBUG} ne "0");

    $list .= "debugSetTokenExpired:noArg "
      if ( $isPasswordSet and $hash->{helper}{DEBUG} ne "0");

    return "Unknown argument $cmd, choose one of $list";
  }
  return undef;
}

#####################################
# GroheOndusSmartBridge_Write( $hash, $param )
sub GroheOndusSmartBridge_Write($$)
{
  my ( $hash, $param ) = @_;
  my $name = $hash->{NAME};
  my $resultCallback = $param->{resultCallback};

  Log3($name, 4, "GroheOndusSmartBridge_Write($name)");

  my $callbackSuccess = sub
  {
    # Add Authorization to Header
    GroheOndusSmartBridge_Header_AddAuthorization( $hash, $param );

    $param->{hash} = $hash;

    GroheOndusSmartBridge_RequestParam( $hash, $param );
  };

  my $callbackFail = sub
  {
    # is there a callback function?
    if(defined($resultCallback))
    {
      my $data = undef;
      my $errorMsg = $_[0];

      $resultCallback->($param, $data, $errorMsg);
    }
  };
  
   GroheOndusSmartBridge_Connect($hash, $callbackSuccess, $callbackFail);
}

#####################################
# GroheOndusSmartBridge_TimerExecute( $hash )
sub GroheOndusSmartBridge_TimerExecute($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};

  GroheOndusSmartBridge_TimerRemove($hash);

  if(!$init_done)
  {
    Log3($name, 5, "GroheOndusSmartBridge_TimerExecute($name) - Init not done yet");

    # reload timer
    my $nextTimer = gettimeofday() + 2;
    $hash->{NEXTTIMER} = strftime($TimeStampFormat, localtime($nextTimer));
    InternalTimer( $nextTimer, \&GroheOndusSmartBridge_TimerExecute, $hash );

    return;
  }

  if ($hash->{helper}{IsDisabled} ne "0")
  {
    Log3($name, 4, "GroheOndusSmartBridge_TimerExecute($name) - Disabled");
  }
  else
  {
    Log3($name, 4, "GroheOndusSmartBridge_TimerExecute($name)");
  
    GroheOndusSmartBridge_GetDevices($hash);

    # reload timer
    my $nextTimer = gettimeofday() + $hash->{INTERVAL};
    $hash->{NEXTTIMER} = strftime($TimeStampFormat, localtime($nextTimer));
    InternalTimer($nextTimer, \&GroheOndusSmartBridge_TimerExecute, $hash);
  }
}

#####################################
# GroheOndusSmartBridge_TimerRemove( $hash )
sub GroheOndusSmartBridge_TimerRemove($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};
  
  Log3($name, 4, "GroheOndusSmartBridge_TimerRemove($name)");
  
  $hash->{NEXTTIMER} = "none";
  RemoveInternalTimer($hash, \&GroheOndusSmartBridge_TimerExecute);
}

#####################################
# GroheOndusSmartBridge_UpdateInternals( $hash )
sub GroheOndusSmartBridge_UpdateInternals($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};

  Log3($name, 5, "GroheOndusSmartBridge_UpdateInternals($name)");
  
  if($hash->{helper}{DEBUG} eq "1")
  {
    $hash->{DEBUG_WRITEMETHOD}              = $hash->{helper}{WRITEMETHOD};
    $hash->{DEBUG_WRITEURL}                 = $hash->{helper}{WRITEURL};
    $hash->{DEBUG_WRITEHEADER}              = $hash->{helper}{WRITEHEADER};
    $hash->{DEBUG_WRITEDATA}                = $hash->{helper}{WRITEDATA};
    $hash->{DEBUG_WRITEHTTPVERSION}         = $hash->{helper}{WRITEHTTPVERSION};
    $hash->{DEBUG_WRITEIGNOREREDIRECTS}     = $hash->{helper}{WRITEIGNOREREDIRECTS};
    $hash->{DEBUG_WRITEKEEPALIVE}           = $hash->{helper}{WRITEKEEPALIVE};

    $hash->{DEBUG_RESPONSECOUNT_SUCCESS}    = $hash->{helper}{RESPONSECOUNT_SUCCESS};
    $hash->{DEBUG_RESPONSECOUNT_ERROR}      = $hash->{helper}{RESPONSECOUNT_ERROR};
    $hash->{DEBUG_RESPONSEAVERAGETIMESPAN}  = $hash->{helper}{RESPONSEAVERAGETIMESPAN};
    my @retrystring_keys =  grep /RESPONSECOUNT_RETRY_/, keys %{$hash->{helper}};
    foreach (@retrystring_keys)
    {
      $hash->{"DEBUG_" . $_} = $hash->{helper}{$_};
    }

    $hash->{DEBUG_refresh_token}            = $hash->{helper}{refresh_token};
    $hash->{DEBUG_access_token}             = $hash->{helper}{access_token};
    $hash->{DEBUG_expires_in}               = $hash->{helper}{expires_in};
    $hash->{DEBUG_token_type}               = $hash->{helper}{token_type};
    $hash->{DEBUG_id_token}                 = $hash->{helper}{id_token};
    $hash->{"DEBUG_not-before-policy"}      = $hash->{helper}{"not-before-policy"};
    $hash->{DEBUG_session_state}            = $hash->{helper}{session_state};
    $hash->{DEBUG_scope}                    = $hash->{helper}{scope};
    $hash->{DEBUG_tandc_accepted}           = $hash->{helper}{tandc_accepted};
    $hash->{DEBUG_partialLogin}             = $hash->{helper}{partialLogin};
    
    $hash->{DEBUG_LOGIN_INPROGRESS}         = $hash->{helper}{LoginInProgress};
    $hash->{DEBUG_LOGIN_NEXTTIMESTAMP}      = $hash->{helper}{LoginNextTimeStamp}
      if(defined($hash->{helper}{LoginNextTimeStamp}));
    $hash->{DEBUG_LOGIN_NEXTTIMESTAMPAT}    = strftime($TimeStampFormat, localtime($hash->{helper}{LoginNextTimeStamp}))
      if(defined($hash->{helper}{LoginNextTimeStamp}));
    $hash->{DEBUG_LOGIN_COUNTER}            = $hash->{helper}{LoginCounter};
    $hash->{DEBUG_LOGIN_COUNTER_ERROR}      = $hash->{helper}{LoginErrCounter};

    $hash->{DEBUG_IsDisabled}               = $hash->{helper}{IsDisabled};
  }
  else
  {
    # delete all keys starting with "DEBUG_"
    my @matching_keys =  grep /DEBUG_/, keys %$hash;
    foreach (@matching_keys)
    {
      delete $hash->{$_};
    }
  }
}

#####################################
# GroheOndusSmartBridge_Connect( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartBridge_Connect($;$$)
{
  my ($hash, $callbackSuccess, $callbackFail) = @_;
  my $name    = $hash->{NAME};
  my $now     = gettimeofday();
  my $message = "";

  if($hash->{helper}{IsDisabled} ne "0")
  {
    Log3($name, 4, "GroheOndusSmartBridge_Connect($name) - IsDisabled");

    # if there is a callback then call it
    if(defined($callbackFail))
    {
      Log3($name, 4, "GroheOndusSmartBridge_Connect($name) - callbackFail");
      $callbackFail->("bridge inactive");
    }
  }
  elsif($hash->{helper}{LoginInProgress} ne "0")
  {
    Log3($name, 4, "GroheOndusSmartBridge_Connect($name) - LoginInProgress");

    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartBridge_Connect($name) - callbackFail");
      $callbackFail->("login in progress");
    }
  }
  else
  {
    Log3($name, 4, "GroheOndusSmartBridge_Connect($name)");
    
    # no valid AccessToken
    if(!defined( $hash->{helper}{access_token}) or
      $hash->{helper}{access_token} eq "none")
    {
      $message = "No valid AccessToken";
    }
    # token has expired
    elsif(!defined($hash->{helper}{LoginNextTimeStamp}) or
      $now >= $hash->{helper}{LoginNextTimeStamp})
    {
      $message = "AccessToken expired - Relogin needed";
    }
  
    if($message eq "")
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Connect($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      Log3($name, 3, "GroheOndusSmartBridge_Connect($name) - $message");

      GroheOndusSmartBridge_Login($hash, $callbackSuccess, $callbackFail);
    }
  }
}

#####################################
# GroheOndusSmartBridge_ClearLogin( $hash )
sub GroheOndusSmartBridge_ClearLogin($)
{
  my ($hash)  = @_;
  my $name    = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_ClearLogin($name)");

  readingsBeginUpdate($hash);
  readingsBulkUpdateIfChanged( $hash, "state", "login cleared", 1 );
  readingsEndUpdate( $hash, 1 );

  # clear $hash->{helper} to reset statemachines
  delete $hash->{helper}{refresh_token};
  delete $hash->{helper}{access_token};
  delete $hash->{helper}{expires_in};
  delete $hash->{helper}{user_id};
  delete $hash->{helper}{loginaddress};
  delete $hash->{helper}{ondusaddress};
  
  delete $hash->{helper}{LoginNextTimeStamp};
}

#####################################
# GroheOndusSmartBridge_Login( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartBridge_Login($;$$)
{
  my ($hash, $callbackSuccess, $callbackFail) = @_;
  my $name      = $hash->{NAME};
  my $errorMsg  = "";

  Log3($name, 4, "GroheOndusSmartBridge_Login($name)");

  # Check for AccountEmail
  if (AttrVal( $name, "groheOndusAccountEmail", "none" ) eq "none")
  {
    $errorMsg = "please set Attribut groheOndusAccountEmail first";
  }
  # Check for Password
  elsif(not defined( GroheOndusSmartBridge_ReadPassword($hash)))
  {
    $errorMsg = "please set grohe account password first";
  }
  elsif($hash->{helper}{LoginInProgress} ne "0")
  {
    $errorMsg = "login in progress";
  }

  GroheOndusSmartBridge_ClearLogin($hash);

  if($errorMsg eq "")
  {
    $hash->{helper}{LoginInProgress}       = "1";
    GroheOndusSmartBridge_UpdateInternals($hash);

    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged( $hash, "state", "logging in", 1 );
    readingsEndUpdate( $hash, 1 );

    my $loginSuccess = sub
    {
      $hash->{helper}{LoginInProgress}       = "0";
      GroheOndusSmartBridge_UpdateInternals($hash);

      # if there is a callback then call it
      if(defined($callbackSuccess))
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login($name) - callbackFail");
        $callbackSuccess->();
      }
    };

    my $loginFail = sub
    {
      $hash->{helper}{LoginInProgress}       = "0";
      GroheOndusSmartBridge_UpdateInternals($hash);

      # if there is a callback then call it
      if(defined($callbackFail))
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    };

    my $login_PostOndusAddress  = sub { GroheOndusSmartBridge_Login_GetToken($hash, $loginSuccess, $loginFail); };
    my $login_PostLoginAddress  = sub { GroheOndusSmartBridge_Login_PostAddress($hash, $login_PostOndusAddress, $loginFail); };
    my $login_GetLoginAddress   = sub { GroheOndusSmartBridge_Login_GetLoginAddress($hash, $login_PostLoginAddress, $loginFail); };
  
    $login_GetLoginAddress->();
  }
  else
  {
    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
    readingsEndUpdate( $hash, 1 );
    
    # if there is a callback then call it
    if(defined($callbackFail))
    {
      Log3($name, 4, "GroheOndusSmartBridge_Login($name) - callbackFail");
      $callbackFail->($errorMsg);
    }
  }
}

#####################################
# GroheOndusSmartBridge_Login_GetLoginAddress( $hash, $callbackSuccess, $callbackFail )
#####################################
sub GroheOndusSmartBridge_Login_GetLoginAddress($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_Login_GetLoginAddress($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    if( $errorMsg eq "")
    {
      if ( $data =~ m/action=\"([^\"]*)\"/ )
      {
        # take first match
        # -> action="https://idp2-apigw.cloud.grohe.com/v1/sso/auth/realms/idm-apigw/login-actions/authenticate?code=XXX;execution=XXX;client_id=iot&amp;tab_id=XXX
        my $formTargetOf = decode_entities($1);
        $hash->{helper}{loginaddress} = $formTargetOf;

        Log3($name, 5, "GroheOndusSmartBridge_Login_GetLoginAddress($name) - Action\n$formTargetOf");

        # find all "Set-Cookie" lines and create cookie header
        GroheOndusSmartBridge_ProcessSetCookies( $hash, $callbackparam->{httpheader}, undef );
      }
      else
      {
        $hash->{helper}{loginaddress} = undef;

        $errorMsg = "LOGIN_GETLOGINADDRESS: WRONG ADDRESS";
      }
    }
    
    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_GetLoginAddress($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_GetLoginAddress($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  }; 

  # GET https://idp2-apigw.cloud.grohe.com/v3/iot/oidc/login HTTP/1.1
  # -> request is being redirected to:
  # GET https://idp2-apigw.cloud.grohe.com/v1/sso/auth/realms/idm-apigw/protocol/openid-connect/auth?redirect_uri=ondus://idp2-apigw.cloud.grohe.com/v3/iot/oidc/token&scope=openid&response_type=code&client_id=iot&state=f425421e-c03c-44d1-ae43-275c5ee94f81 HTTP/1.1

  my $param = {};
  $param->{method}          = "GET";
  $param->{url}             = $LoginURL;
  $param->{header}          = "";
  $param->{data}            = "";
  $param->{httpversion}     = "1.1";
  $param->{ignoreredirects} = 0;
  $param->{keepalive}       = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;
  
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_Login_PostAddress( $hash, $callbackSuccess, $callbackFail )
#####################################
sub GroheOndusSmartBridge_Login_PostAddress($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_Login_PostAddress($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    Log3($name, 5, "GroheOndusSmartBridge_Login_PostAddress($name) - Login\n$callbackparam->{httpheader}");

    if( $errorMsg eq "" )
    {
      # find Location-entry in header
      if ( $callbackparam->{httpheader} =~ m/Location: ondus:([^\"]*)\n/ )
      {
        # take first match and replace "Location: ondus:" with "https:"
        my $location = "https:" . $1;

        # remove last trailing newline
        $location =~ s/\r|\n//g;

        Log3($name, 5, "GroheOndusSmartBridge_Login_PostAddress($name) - Login Location\n\"$location\"");
        $hash->{helper}{ondusaddress} = $location;

        # find all "Set-Cookie" lines and create cookie header
        GroheOndusSmartBridge_ProcessSetCookies($hash, $callbackparam->{httpheader}, "AWSALB");
        #GroheOndusSmartBridge_ProcessSetCookies( $hash, $callbackparam->{httpheader}, undef );
      }
      # Invalid email address or password? 
      elsif ( $data =~ m/Invalid email address or password/ )
      {
        Log3($name, 5, "GroheOndusSmartBridge_Login_PostAddress($name) - Login - Invalid email address or password");

        $errorMsg = "Invalid email address or password";
      }
      else
      {
        $hash->{helper}{ondusaddress} = undef;

        $errorMsg = "LOGIN_POSTADDRESS: WRONG ADDRESS";
      }
    }

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_PostAddress($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_PostAddress($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  }; 

  my $param = {};
  $param->{method} = "POST";
  $param->{url}    = $hash->{helper}{loginaddress};
  $param->{header} = "Content-Type: application/x-www-form-urlencoded";
  $param->{data} = "username=" . urlEncode( AttrVal( $name, "groheOndusAccountEmail", "none" ) ) . "&password=" . urlEncode( GroheOndusSmartBridge_ReadPassword($hash) );
  $param->{httpversion} = "1.1";
  $param->{ignoreredirects} = 1;
  $param->{keepalive} = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;

  GroheOndusSmartBridge_Header_AddCookies( $hash, $param );
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_Login_GetToken( $hash, $callbackSuccess, $callbackFail )
#####################################
sub GroheOndusSmartBridge_Login_GetToken($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  my $now = gettimeofday();
  Log3($name, 4, "GroheOndusSmartBridge_Login_GetToken($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    if( $errorMsg eq "" )
    {
      # {
      #   "access_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #   "expires_in":3600,
      #   "refresh_expires_in":15552000,
      #   "refresh_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #   "token_type":"bearer",
      #   "id_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #   "not-before-policy":0,
      #   "session_state":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      #   "scope":"",
      #   "tandc_accepted":true,
      #   "partialLogin":false
      # }

      # get json-structure from data-string
      my $decode_json = eval { decode_json($data) };
      if ($@)
      {
        Log3($name, 3, "GroheOndusSmartBridge_Login_GetToken($name) - JSON error while request: $@");

        if ( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, "JSON_ERROR", $@, 1 );
          readingsBulkUpdate( $hash, "JSON_ERROR_STRING", "\"" . $data . "\"", 1 );
          readingsEndUpdate( $hash, 1 );
        }

        $errorMsg = "JSON_ERROR";
      }
      elsif ( ref($decode_json) eq "HASH" and
        defined( $decode_json->{refresh_token} ) )
      {
        $hash->{helper}{refresh_token} = $decode_json->{refresh_token};
        $hash->{helper}{access_token} = $decode_json->{access_token};
        $hash->{helper}{expires_in} = $decode_json->{expires_in};
        $hash->{helper}{token_type} = $decode_json->{token_type};
        $hash->{helper}{id_token} = $decode_json->{id_token};
        $hash->{helper}{"not-before-policy"} = $decode_json->{"not-before-policy"};
        $hash->{helper}{session_state} = $decode_json->{session_state};
        $hash->{helper}{scope} = $decode_json->{scope};
        $hash->{helper}{tandc_accepted} = $decode_json->{tandc_accepted};
        $hash->{helper}{partialLogin} = $decode_json->{partialLogin};

        my $loginNextTimeStamp = $now + $decode_json->{expires_in} + $ReloginOffset_s;
        $hash->{helper}{LoginNextTimeStamp} = $loginNextTimeStamp; 
        $hash->{helper}{LoginCounter}++;
        
        Log3($name, 5, "GroheOndusSmartBridge_Login_GetToken($name) - RefreshToken\n$hash->{helper}{refresh_token}");

        # find all "Set-Cookie" lines and create cookie header
        #ProcessSetCookies($hash, $param->{httpheader}, "AWSALB");
        GroheOndusSmartBridge_ProcessSetCookies( $hash, $callbackparam->{httpheader}, undef );
      }
      else
      {
        $hash->{helper}{refresh_token} = undef;
        $hash->{helper}{access_token} = undef;
        $hash->{helper}{expires_in} = undef;
        $hash->{helper}{token_type} = undef;
        $hash->{helper}{id_token} = undef;
        $hash->{helper}{"not-before-policy"} = undef;
        $hash->{helper}{session_state} = undef;
        $hash->{helper}{scope} = undef;
        $hash->{helper}{tandc_accepted} = undef;
        $hash->{helper}{partialLogin} = undef;

        my $loginNextTimeStamp = $now;
        $hash->{helper}{LoginNextTimeStamp} = $loginNextTimeStamp; 
        $hash->{helper}{LoginErrCounter}++;

        $errorMsg = "LOGIN_GETTOKEN: WRONG JSON STRUCTURE";
      }

      GroheOndusSmartBridge_UpdateInternals($hash);
    }

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "logged in", 1 );
      readingsEndUpdate( $hash, 1 );

      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_GetToken($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );
      
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_GetToken($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  }; 

  my $param = {};
  $param->{method} = "GET";
  $param->{url}    = $hash->{helper}{ondusaddress};
  $param->{header} = "";
  $param->{httpversion} = "1.1";
  $param->{ignoreredirects} = 0;
  $param->{keepalive} = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;

  GroheOndusSmartBridge_Header_AddCookies( $hash, $param );
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_Login_Refresh( $hash, $callbackSuccess, $callbackFail )
#####################################
sub GroheOndusSmartBridge_Login_Refresh($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_Login_Refresh($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    if( $errorMsg eq "" )
    {
      # {
      #   "access_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #   "expires_in":3600,
      #   "refresh_expires_in":15552000,
      #   "refresh_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #   "token_type":"bearer",
      #   "id_token":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #   "not-before-policy":0,
      #   "session_state":"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      #   "scope":"",
      #   "tandc_accepted":true
      # }

      # get json-structure from data-string
      my $decode_json = eval { decode_json($data) };
      if ($@)
      {
        Log3($name, 3, "GroheOndusSmartBridge_Login_Refresh($name) - JSON error while request: $@");

        if ( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, "JSON_ERROR", $@, 1 );
          readingsBulkUpdate( $hash, "JSON_ERROR_STRING", "\"" . $data . "\"", 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "JSON_ERROR";
      }
      elsif ( ref($decode_json) eq "HASH" and
        defined( $decode_json->{access_token} ) )
      {
        $hash->{helper}{access_token} = $decode_json->{access_token};
        $hash->{helper}{expires_in} = $decode_json->{expires_in};
        $hash->{helper}{refresh_expires_in} = $decode_json->{refresh_expires_in};
        $hash->{helper}{refresh_token} = $decode_json->{refresh_token};
        $hash->{helper}{token_type} = $decode_json->{token_type};
        $hash->{helper}{id_token} = $decode_json->{id_token};
        $hash->{helper}{"not-before-policy"} = $decode_json->{"not-before-policy"};
        $hash->{helper}{session_state} = $decode_json->{session_state};
        $hash->{helper}{scope} = $decode_json->{scope};
        $hash->{helper}{tandc_accepted} = $decode_json->{tandc_accepted};

        Log3($name, 5, "GroheOndusSmartBridge_Login_Refresh($name) - RefreshToken\n$hash->{helper}{refresh_token}");

        # find all "Set-Cookie" lines and create cookie header
        #ProcessSetCookies($hash, $callbackparam->{httpheader}, "AWSALB");
        ProcessSetCookies( $hash, $callbackparam->{httpheader}, undef );
      }
      else
      {
        $hash->{helper}{access_token} = undef;
        $hash->{helper}{expires_in} = undef;
        $hash->{helper}{refresh_expires_in} = undef;
        $hash->{helper}{refresh_token} = undef;
        $hash->{helper}{token_type} = undef;
        $hash->{helper}{id_token} = undef;
        $hash->{helper}{"not-before-policy"} = undef;
        $hash->{helper}{session_state} = undef;
        $hash->{helper}{scope} = undef;
        $hash->{helper}{tandc_accepted} = undef;

        $errorMsg = "LOGIN_REFRESH: WRONG JSON STRUCTURE";
      }

      GroheOndusSmartBridge_UpdateInternals( $hash );
    }

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "logged in", 1 );
      readingsEndUpdate( $hash, 1 );

      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_Refresh($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );
      
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_Login_Refresh($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  }; 

  my $jsondata = { "refresh_token" => $hash->{helper}{refresh_token} };

  my $param = {};
  $param->{method}          = "POST";
  $param->{url}             = $hash->{URL} . "/iot/oidc/refresh";
  $param->{header}          = "Content-Type: application/json; charset=utf-8";
  $param->{data}            = encode_json($jsondata);
  $param->{httpversion}     = "1.1";
  $param->{ignoreredirects} = 0;
  $param->{keepalive}       = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;

  GroheOndusSmartBridge_Header_AddCookies( $hash, $param );
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_GetDevices( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartBridge_GetDevices($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_GetDevices($name) - fetch device list and device states");

  $hash->{helper}{CountAppliances} = 0;
  $hash->{helper}{CountRooms} = 0;
  $hash->{helper}{CountLocations} = 0;

  my $getAppliances = sub { GroheOndusSmartBridge_GetAppliances($hash, $_[0], $_[1], $callbackSuccess, $callbackFail); };
  my $getRooms = sub { GroheOndusSmartBridge_GetRooms($hash, $_[0], $getAppliances, $callbackFail); };
  my $getLocations = sub { GroheOndusSmartBridge_GetLocations($hash, $getRooms, $callbackFail); };
  my $connect = sub { GroheOndusSmartBridge_Connect($hash, $getLocations, $callbackFail); };
  $connect->();
}

#####################################
# GroheOndusSmartBridge_GetLocations( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartBridge_GetLocations($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_GetLocations($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    if( $errorMsg eq "")
    {
      my $decode_json = eval { decode_json($data) };
      if ($@)
      {
        Log3($name, 3, "GroheOndusSmartBridge_GetLocations($name) - JSON error while request: $@");

        if ( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, "JSON_ERROR", $@, 1 );
          readingsBulkUpdate( $hash, "JSON_ERROR_STRING", "\"" . $data . "\"", 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETLOCATIONS: JSON_ERROR";
      }
      # locations
      elsif ( ref($decode_json) eq "ARRAY"
        and scalar( @{$decode_json} ))
      {
        #[
        #   {
        #       "id":48434,
        #       "name":"Haus",
        #       "type":2,
        #       "role":"owner",
        #       "timezone":"Europe/Berlin",
        #       "water_cost":-1,
        #       "energy_cost":-1,
        #       "heating_type":-1,
        #       "currency":"EUR",
        #       "default_water_cost":0.004256,
        #       "default_energy_cost":0.003977,
        #       "default_heating_type":2,
        #       "emergency_shutdown_enable":true,
        #       "address":
        #       {
        #           "street":"Straﬂe 5",
        #           "city":"Dorf",
        #           "zipcode":"123456",
        #           "housenumber":"",
        #           "country":"Deutschland",
        #           "country_code":"DE",
        #           "additionalInfo":""
        #       }
        #   }
        #]

        foreach my $location ( @{$decode_json} )
        {
          $hash->{helper}{CountLocations}++;

          # fetch rooms within current location
          #Write( $hash, undef, undef, "smartbridge" );

          # if there is a callback then call it
          if( defined($callbackSuccess) )
          {
            Log3($name, 4, "GroheOndusSmartBridge_GetLocations($name) - callbackSuccess");
            $callbackSuccess->($location->{id});
          }
        }

        Log3($name, 5, "GroheOndusSmartBridge_GetLocations($name) - locations count " . $hash->{helper}{CountLocations});

        # update reading
        readingsSingleUpdate( $hash, "count_locations", $hash->{helper}{CountLocations}, 0 );
      }
      else
      {
        $errorMsg = "GETLOCATIONS: WRONG JSON STRUCTURE";
      }
    }
    
    if( $errorMsg eq "" )
    {
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );
      
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_GetLocations($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  }; 

  my $param = {};
  $param->{method}          = "GET";
  $param->{url}             = $hash->{URL} . "/iot/locations";
  $param->{header}          = "Content-Type: application/json";
  $param->{data}            = "{}";
  $param->{httpversion}     = "1.0";
  $param->{ignoreredirects} = 0;
  $param->{keepalive}       = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;

  GroheOndusSmartBridge_Header_AddAuthorization( $hash, $param );
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_GetRooms( $hash, $current_location_id, $callbackSuccess, $callbackFail )
sub GroheOndusSmartBridge_GetRooms($$;$$)
{
  my ( $hash, $current_location_id, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_GetRooms($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    if( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
      if ($@)
      {
        Log3($name, 3, "GroheOndusSmartBridge_GetRooms($name) - JSON error while request: $@");

        if ( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, "JSON_ERROR", $@, 1 );
          readingsBulkUpdate( $hash, "JSON_ERROR_STRING", "\"" . $data . "\"", 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETROOMS: JSON_ERROR";
      }
      # rooms
      elsif ( ref($decode_json) eq "ARRAY" and
        scalar( @{$decode_json} ) > 0)
      {
        #[
        #   {
        #       "id":12345,
        #       "name":"EG K¸che",
        #       "type":0,
        #       "room_type":15,
        #       "role":"owner"
        #   }
        #]

        foreach my $room ( @{$decode_json} )
        {
          $hash->{helper}{CountRooms}++;

          # fetch appliances within current room
          #  Write( $hash, undef, undef, "smartbridge" );

          # if there is a callback then call it
          if( defined($callbackSuccess) )
          {
            Log3($name, 4, "GroheOndusSmartBridge_GetRooms($name) - GetLocations callbackSuccess");
            $callbackSuccess->($current_location_id, $room->{id});
          }
        }

        Log3($name, 5, "GroheOndusSmartBridge_GetRooms($name) - rooms count " . $hash->{helper}{CountRooms});

        # update reading
        readingsSingleUpdate( $hash, "count_rooms", $hash->{helper}{CountRooms}, 0 );
      }
    }

    if( $errorMsg eq "" )
    {
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );
      
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_GetRooms($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  }; 

  my $param = {};
  $param->{method}          = "GET";
  $param->{url}             = $hash->{URL} . "/iot/locations/" . $current_location_id . "/rooms";
  $param->{header}          = "Content-Type: application/json";
  $param->{data}            = "{}";
  $param->{httpversion}     = "1.0";
  $param->{ignoreredirects} = 0;
  $param->{keepalive}       = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;

  GroheOndusSmartBridge_Header_AddAuthorization( $hash, $param );
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_GetAppliances( $hash, $current_location_id, $current_room_id, $callbackSuccess, $callbackFail )
#####################################
sub GroheOndusSmartBridge_GetAppliances($$$;$$)
{
  my ( $hash, $current_location_id, $current_room_id, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_GetAppliances($name)");

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $decode_json = eval { decode_json($data) };
    if ($@)
    {
      Log3($name, 3, "GroheOndusSmartBridge_GetAppliances($name) - JSON error while request: $@");

      if ( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "JSON_ERROR", $@, 1 );
        readingsBulkUpdate( $hash, "JSON_ERROR_STRING", "\"" . $data . "\"", 1 );
        readingsEndUpdate( $hash, 1 );
      }
      $errorMsg = "GETAPPLIANCES: JSON_ERROR";
    }
    # appliances
    elsif ( ref($decode_json) eq "ARRAY"
      and scalar( @{$decode_json} ) > 0 )
    {
      #[
      #   {
      #       "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      #       "installation_date":"2001-01-30T00:00:00.000+00:00",
      #       "name":"KG Vorratsraum - SenseGUARD",
      #       "serial_number":"123456789012345678901234567890123456789012345678",
      #       "type":103,
      #       "version":"01.38.Z22.0400.0101",
      #       "tdt":"2019-06-30T11:06:40.000+02:00",
      #       "timezone":60,
      #       "config":
      #       {
      #           "thresholds":
      #           [
      #               {
      #                   "quantity":"flowrate",
      #                   "type":"min",
      #                   "value":3,
      #                   "enabled":false
      #               },
      #               {
      #                   "quantity":"flowrate",
      #                   "type":"max",
      #                   "value":50,
      #                   "enabled":true
      #               },
      #               {
      #                   "quantity":"pressure",
      #                   "type":"min",
      #                   "value":2,
      #                   "enabled":false
      #               },
      #               {
      #                   "quantity":"pressure",
      #                   "type":"max",
      #                   "value":8,
      #                   "enabled":false
      #               },
      #               {
      #                   "quantity":"temperature_guard",
      #                   "type":"min",
      #                   "value":5,
      #                   "enabled":false
      #               },
      #               {
      #                   "quantity":"temperature_guard",
      #                   "type":"max",
      #                   "value":45,
      #                   "enabled":false
      #               }
      #           ],
      #       "measurement_period":900,
      #       "measurement_transmission_intervall":900,
      #       "measurement_transmission_intervall_offset":1,
      #       "action_on_major_leakage":1,
      #       "action_on_minor_leakage":1,
      #       "action_on_micro_leakage":0,
      #       "monitor_frost_alert":true,
      #       "monitor_lower_flow_limit":false,
      #       "monitor_upper_flow_limit":true,
      #       "monitor_lower_pressure_limit":false,
      #       "monitor_upper_pressure_limit":false,
      #       "monitor_lower_temperature_limit":false,
      #       "monitor_upper_temperature_limit":false,
      #       "monitor_major_leakage":true,
      #       "monitor_minor_leakage":true,
      #       "monitor_micro_leakage":true,
      #       "monitor_system_error":false,
      #       "monitor_btw_0_1_and_0_8_leakage":true,
      #       "monitor_withdrawel_amount_limit_breach":true,
      #       "detection_interval":11250,
      #       "impulse_ignore":10,
      #       "time_ignore":20,
      #       "pressure_tolerance_band":10,
      #       "pressure_drop":50,
      #       "detection_time":30,
      #       "action_on_btw_0_1_and_0_8_leakage":1,
      #       "action_on_withdrawel_amount_limit_breach":1,
      #       "withdrawel_amount_limit":300,
      #       "sprinkler_mode_start_time":0,
      #       "sprinkler_mode_stop_time":1439,
      #       "sprinkler_mode_active_monday":false,
      #       "sprinkler_mode_active_tuesday":false,
      #       "sprinkler_mode_active_wednesday":false,
      #       "sprinkler_mode_active_thursday":false,
      #       "sprinkler_mode_active_friday":false,
      #       "sprinkler_mode_active_saturday":false,
      #       "sprinkler_mode_active_sunday":false},
      #       "role":"owner",
      #       "registration_complete":true,
      #       "calculate_average_since":"2000-01-30T00:00:00.000Z"
      #   },
      #   {
      #       "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      #       "installation_date":"2001-01-30T00:00:00.000+00:00",
      #       "name":"KG Vorratsraum Sense",
      #       "serial_number":"123456789012345678901234567890123456789012345678",
      #       "type":101,
      #       "version":"1547",
      #       "tdt":"2019-06-30T05:15:38.000+02:00",
      #       "timezone":60,
      #       "config":
      #       {
      #           "thresholds":
      #           [
      #               {
      #                   "quantity":"temperature",
      #                   "type":"min",
      #                   "value":10,
      #                   "enabled":true
      #               },
      #               {
      #                   "quantity":"temperature",
      #                   "type":"max",
      #                   "value":35,
      #                   "enabled":true
      #               },
      #               {
      #                   "quantity":"humidity",
      #                   "type":"min",
      #                   "value":30,
      #                   "enabled":true
      #               },
      #               {
      #                   "quantity":"humidity",
      #                   "type":"max",
      #                   "value":65,
      #                   "enabled":true
      #               }
      #           ]
      #       },
      #       "role":"owner",
      #       "registration_complete":true
      #   }
      #]

      foreach my $appliance ( @{$decode_json} )
      {
        $hash->{helper}{CountAppliances}++;

        my $current_appliance_id = $appliance->{appliance_id};
        my $current_type_id = $appliance->{type};
        my $current_name = $appliance->{name};
        
        # save current appliance in list
        $hash->{helper}{appliance_list}{ $current_appliance_id } = 
        {
          appliance_id => $current_appliance_id,
          type_id => $current_type_id,
          name     => $current_name,
          location_id => $current_location_id,
          room_id     => $current_room_id,
          appliance   => encode_json($appliance),
        };
        
        # to pass parameters to the underlying logical device
        # the hash "currentAppliance" is set for the moment
        $hash->{currentAppliance} = 
        {
          appliance_id => $current_appliance_id,
          type_id      => $current_type_id,
          name         => $current_name,
          location_id  => $current_location_id,
          room_id      => $current_room_id,
          autocreate   => $hash->{helper}{AUTOCREATEDEVICES}
        };
        
        # dispatch to GroheOndusSmartDevice::Parse()
        my $found = Dispatch( $hash, "GROHEONDUSSMARTDEVICE_" . $current_appliance_id, undef );
        
        # If a new device was created $found is undef.
        # So dispatch again to get the new created device in running state.
        if(not defined($found))
        {
          Dispatch( $hash, "GROHEONDUSSMARTDEVICE_" . $current_appliance_id, undef );
        }

        # delete it again
        delete $hash->{currentAppliance}; 
      }

      Log3($name, 5, "GroheOndusSmartBridge_GetAppliances($name) - appliances count " . $hash->{helper}{CountAppliances});

      readingsSingleUpdate( $hash, "count_appliance", $hash->{helper}{CountAppliances}, 0 );
    }
    else
    {
      $errorMsg = "GETAPPLIANCES: WRONG JSON STRUCTURE";
    }
     
    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", "connected to cloud", 1 );
      readingsEndUpdate( $hash, 1 );

      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_GetAppliances($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
      readingsEndUpdate( $hash, 1 );
      
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartBridge_GetAppliances($name) - callbackFail");
        $callbackFail->($errorMsg);
      }
    }
  };
  
  my $param = {};
  $param->{method}          = "GET";
  $param->{url}             = $hash->{URL} . "/iot/locations/" . $current_location_id . "/rooms/" . $current_room_id . "/appliances";
  $param->{header}          = "Content-Type: application/json";
  $param->{data}            = "{}";
  $param->{httpversion}     = "1.0";
  $param->{ignoreredirects} = 0;
  $param->{keepalive}       = 1;

  $param->{hash} = $hash;
  $param->{resultCallback} = $resultCallback;

  GroheOndusSmartBridge_Header_AddAuthorization( $hash, $param );
  GroheOndusSmartBridge_RequestParam( $hash, $param );
}

#####################################
# GroheOndusSmartBridge_RequestParam( $hash, $param )
sub GroheOndusSmartBridge_RequestParam($$)
{
  my ( $hash, $param ) = @_;
  my $name = $hash->{NAME};
  my $resultCallback = $param->{resultCallback};

  Log3($name, 4, "GroheOndusSmartBridge_RequestParam($name)");

  if( $hash->{helper}{IsDisabled} ne "0" )
  {
    # is there a callback function?
    if(defined($resultCallback))
    {
      my $data = undef;
      my $errorMsg = "Bridge inactive";

      $resultCallback->($param, $data, $errorMsg);
    }
  }
  else
  {
    $param->{compress} = 0;
    $param->{doTrigger} = 1;
    $param->{callback} = \&GroheOndusSmartBridge_RequestErrorHandling;
    
    $param->{resultCallback} = $resultCallback;
    $param->{retryCallback} = \&GroheOndusSmartBridge_SendReceive;
    $param->{leftRetries} = $hash->{RETRIES};

    $hash->{helper}{WRITEMETHOD}          = $param->{method};
    $hash->{helper}{WRITEURL}             = $param->{url};
    $hash->{helper}{WRITEHEADER}          = $param->{header};
    $hash->{helper}{WRITEDATA}            = $param->{data};
    $hash->{helper}{WRITEHTTPVERSION}     = $param->{httpversion};
    $hash->{helper}{WRITEIGNOREREDIRECTS} = $param->{ignoreredirects};
    $hash->{helper}{WRITEKEEPALIVE}       = $param->{keepalive};

    GroheOndusSmartBridge_UpdateInternals($hash);

    GroheOndusSmartBridge_SendReceive($hash, $param);
  }
}

#####################################
# GroheOndusSmartBridge_SendReceive( $hash, $param )
sub GroheOndusSmartBridge_SendReceive($$)
{
  my ( $hash, $param ) = @_;
  my $name = $hash->{NAME};

  $param->{request_timestamp} = gettimeofday();
  $param->{leftRetries}--;

  my $request_id = $hash->{REQUESTID}++;
  
  if($request_id >= 65536)
  {
    $hash->{REQUESTID} = 0;
    $request_id = 0;
  }
  $param->{request_id} = $request_id;

  HttpUtils_NonblockingGet($param);
};

#####################################
# GroheOndusSmartBridge_RequestErrorHandling( $param, $err, $data )
sub GroheOndusSmartBridge_RequestErrorHandling($$$)
{
  my ( $param, $err, $data ) = @_;

  my $request_id  = $param->{request_id};
  my $leftRetries = $param->{leftRetries};
  my $retryCallback = $param->{retryCallback};
  my $resultCallback = $param->{resultCallback};

  my $response_timestamp = gettimeofday();
  my $request_timestamp = $param->{request_timestamp};
  my $requestResponse_timespan = $response_timestamp - $request_timestamp;
  my $errorMsg = "";

  my $hash  = $param->{hash};
  my $name  = $hash->{NAME};
  my $dhash = $hash;

  $dhash = $modules{GroheOndusSmartDevice}{defptr}{ $param->{"device_id"} }
    unless ( not defined( $param->{"device_id"} ) );

  my $dname = $dhash->{NAME};

  Log3($name, 4, "GroheOndusSmartBridge_RequestErrorHandling($name) ");

  ### check error variable
  if ( defined($err) and 
    $err ne "" )
  {
    Log3($name, 3, "GroheOndusSmartBridge_RequestErrorHandling($dname) - ErrorHandling[ID:$request_id]: Error: " . $err . " data: \"" . $data . "\"");
    
    $errorMsg = "error " . $err;
  }

  my $code = "none";
  
  ### check code
  if (exists( $param->{code} ) )
  {
    $code = "$param->{code}";

    if( $param->{code} == 200 ) ###
    {
    }
    elsif( $param->{code} == 302 ) ###
    {
    }
    elsif( $param->{code} == 403 ) ### Forbidden
    {
      #$errorMsg = "wrong password";
      #$leftRetries = 0; # no retry
    }
    elsif( $param->{code} == 429 ) ### To many requests
    {
      $errorMsg = "To many requests";
      $leftRetries = 0; # no retry
    }
    elsif( $param->{code} == 503 ) ### Service Unavailable
    {
      $errorMsg = "error " . $param->{code};
    }
    elsif( $param->{code} == -1 ) ### Debugging
    {
      $errorMsg = "DebuggingLeak";
    }
    elsif( $data eq "" )
    {
      $errorMsg = "error " . $param->{code};
    }
    else
    {
      # no error
    }
  }

  Log3($name, 5, "GroheOndusSmartBridge_RequestErrorHandling($dname) - ErrorHandling[ID:$request_id]: Code: " . $code . " data: \"" . $data . "\"");

  ### no error: process response
  if($errorMsg eq "")
  {
    $hash->{helper}{RESPONSECOUNT_SUCCESS}++;
    $hash->{helper}{RESPONSETOTALTIMESPAN} += $requestResponse_timespan;
    $hash->{helper}{RESPONSEAVERAGETIMESPAN} = $hash->{helper}{RESPONSETOTALTIMESPAN} / $hash->{helper}{RESPONSECOUNT_SUCCESS};
    my $retrystring = "RESPONSECOUNT_RETRY_" . ($hash->{RETRIES} - $leftRetries);
    $hash->{helper}{$retrystring}++;

    GroheOndusSmartBridge_UpdateInternals($hash);
  }
  ### error: retries left
  elsif(defined($retryCallback) and # is retryCallbeck defined
    $leftRetries > 0)               # are there any left retries
  {
    Log3($name, 5, "GroheOndusSmartBridge_RequestErrorHandling($dname) - ErrorHandling[ID:$request_id]: retry " . $leftRetries . " Error: " . $errorMsg);

    ### call retryCallback with decremented number of left retries
    $retryCallback->($hash, $param);
    return; # resultCallback is handled in retry 
  }
  else
  {
    Log3($name, 3, "GroheOndusSmartBridge_RequestErrorHandling($dname) - ErrorHandling[ID:$request_id]: no retries left Error: " . $errorMsg);

    $hash->{helper}{RESPONSECOUNT_ERROR}++;

    GroheOndusSmartBridge_UpdateInternals($hash);

    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged( $hash, "state", $errorMsg, 1 );
    readingsEndUpdate( $hash, 1 );
  }
  
    # is there a callback function?
  if(defined($resultCallback))
  {
    Log3($name, 4, "GroheOndusSmartBridge_RequestErrorHandling($dname) - ErrorHandling[ID:$request_id]: calling lambda function");
    
    $resultCallback->($param, $data, $errorMsg);
  }
}

#####################################
# GroheOndusSmartBridge_ProcessSetCookies( $hash, $header, $regex )
# find all "Set-Cookie" entries in header and put them as "Cookie:" entry in $hash->{helper}{cookie}.
# So cookies can easily added to new outgoing telegrams.
sub GroheOndusSmartBridge_ProcessSetCookies($@)
{
  my ( $hash, $header, $regex ) = @_;

  # delete cookie
  delete $hash->{helper}{cookie}
    if ( defined( $hash->{helper}{cookie} )
    and $hash->{helper}{cookie} );

  # extract all Cookies and save them as string beginning with keyword "Cookie:"
  my $cookie          = "Cookie:";
  my $cookieseparator = " ";

  for ( split( "\r\n", $header ) )    # split header in lines
  {
    # regex: if current string begins with "Set-Cookie"
    if (/^Set-Cookie/)
    {
      my $currentLine    = $_;
      my $currentCookie  = "";
      my $currentVersion = "";
      my $currentPath    = "";

      for ( split( ";", $currentLine ) )    # split current line at ";"
      {
        # trim: remove white space from both ends of a string:
        $_ =~ s/^\s+|\s+$//g;

        my $currentPart = $_;
        $_ .= "DROPME";                     #endmarker to find empty path

        # if current part starts with "Set-Cookie"
        if (/^Set-Cookie/)
        {
          # cut string "Set-Cookie: "
          $currentPart =~ s/Set-Cookie: //;
          $currentCookie = $currentPart;
        }

        # if current part starts with "Version"
        elsif (/^Version/)
        {
          $currentVersion = '$' . $currentPart . '; ';
        }

        # if current part starts with "Path=/"
        elsif (/^Path=\/DROPME/)
        {
          #drop
        }

        # if current part starts with "Path"
        elsif (/^Path/)
        {
          $currentPath = '; $' . $currentPart;
        } else
        {
          #drop
        }
      }

      if ( !defined($regex)
        || $currentCookie =~ m/$regex/si )
      {
        $currentCookie = $currentVersion . $currentCookie . $currentPath;

        $cookie .= "$cookieseparator" . "$currentCookie";
        $cookieseparator = "; ";

        # Set cookie
        $hash->{helper}{cookie} = $cookie;
      }
    }
  }
}

#####################################
# GroheOndusSmartBridge_Header_AddAuthorization( $hash, $param )
sub GroheOndusSmartBridge_Header_AddAuthorization($$)
{
  my ( $hash, $param ) = @_;

  my $header = $param->{header};
  
  # if there is a token, put it in header
  if ( defined( $hash->{helper}{access_token} ) )
  {
    # newline needed?
    $header .= "\n"
      if($header ne "");

    $header .= "Authorization: Bearer " . $hash->{helper}{access_token};
    
    $param->{header} = $header;
  }
}

#####################################
# GroheOndusSmartBridge_Header_AddCookies( $hash, $param )
sub GroheOndusSmartBridge_Header_AddCookies($$)
{
  my ( $hash, $param ) = @_;
  #my $hash = $param->{hash};

  my $header = $param->{header};
  
  # if there is a token, put it in header
  if ( defined( $hash->{helper}{cookie}) )
  {
    # newline needed?
    $header .= "\n"
      if($header ne "");

    $header .= "$hash->{helper}{cookie}";
    
    $param->{header} = $header;
  }
}

#####################################
# GroheOndusSmartBridge_StorePassword( $hash, $password )
sub GroheOndusSmartBridge_StorePassword($$)
{
  my ( $hash, $password ) = @_;
  my $name = $hash->{NAME};
  my $index   = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
  my $key     = getUniqueId() . $index;
  my $enc_pwd = "";

  Log3($name, 5, "GroheOndusSmartBridge_StorePassword($name)");

  if ( eval "use Digest::MD5;1" )
  {
    $key = Digest::MD5::md5_hex( unpack "H*", $key );
    $key .= Digest::MD5::md5_hex($key);
  }

  for my $char ( split //, $password )
  {
    my $encode = chop($key);
    $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
    $key = $encode . $key;
  }

  my $err = setKeyValue( $index, $enc_pwd );

  return "error while saving the password - $err"
    if ( defined($err) );

  return "password successfully saved";
}

#####################################
# GroheOndusSmartBridge_ReadPassword( $hash )
sub GroheOndusSmartBridge_ReadPassword($)
{
  my ( $hash ) = @_;
  my $name   = $hash->{NAME};
  my $index  = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
  my $key    = getUniqueId() . $index;
  my ( $password, $err );

  Log3($name, 5, "GroheOndusSmartBridge_ReadPassword($name)");

  ( $err, $password ) = getKeyValue($index);

  if ( defined($err) )
  {
    Log3($name, 3, "GroheOndusSmartBridge_ReadPassword($name) - unable to read password from file: $err");
    return undef;
  }

  if ( defined($password) )
  {
    if ( eval "use Digest::MD5;1" )
    {
      $key = Digest::MD5::md5_hex( unpack "H*", $key );
      $key .= Digest::MD5::md5_hex($key);
    }

    my $dec_pwd = "";

    for my $char ( map { pack( "C", hex($_) ) } ( $password =~ /(..)/g ) )
    {
      my $decode = chop($key);
      $dec_pwd .= chr( ord($char) ^ ord($decode) );
      $key = $decode . $key;
    }

    return $dec_pwd;
  } 
  else
  {
    Log3($name, 3, "GroheOndusSmartBridge_ReadPassword($name) - No password in file");
    return undef;
  }
}

#####################################
# GroheOndusSmartBridge_DeletePassword( $hash )
sub GroheOndusSmartBridge_DeletePassword($)
{
  my ( $hash ) = @_;
  my $name   = $hash->{NAME};

  setKeyValue( $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd", undef );

  return undef;
}


=pod
=item device
=item summary module to communicate with the GroheOndusCloud
=begin html

  <a name="GroheOndusSmartBridge"></a><h3>GroheOndusSmartBridge</h3>
  <ul>
    In combination with the FHEM module <a href="#GroheOndusSmartDevice">GroheOndusSmartDevice</a> this module communicates with the <b>Grohe-Cloud</b>.<br>
    <br>
    You can get the configurations and measured values of the registered <b>Sense</b> und <b>SenseGuard</b> appliances 
    and i.E. open/close the valve of a <b>SenseGuard</b> appliance.<br>
    <br>
    Once the <b>GroheOndusSmartBridge</b> is created the connected devices are recognized and created automatically in FHEM.<br>
    From now on the devices can be controlled and changes in the <b>GroheOndusAPP</b> are synchronized with the state and readings of the devices.
    <br>
    <br>
    <b>Notes</b>
    <ul>
      <li>This module communicates with the <b>Grohe-Cloud</b> - you have to be registered.
      </li>
      <li>Register your account directly at grohe - don't use "Sign in with Apple/Google/Facebook" or something else.
      </li>
      <li>There is a <b>debug-mode</b> you can enable/disable with the <b>attribute debug</b> to see more internals.
      </li>
    </ul>
    <br>
    <a name="GroheOndusSmartBridge"></a><b>Define</b>
    <ul>
      <code><B>define &lt;name&gt; GroheOndusSmartBridge</B></code>
      <br><br>
      Example:<br>
      <ul>
        <code>
        define GroheBridge GroheOndusSmartBridge<br>
        <br>
        </code>
      </ul>
    </ul><br>
    <a name="GroheOndusSmartBridge"></a><b>Set</b>
    <ul>
      <li><a name="GroheOndusSmartBridgegroheOndusAccountPassword">groheOndusAccountPassword</a><br>
        Set the password and store it.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedeleteAccountPassword">deleteAccountPassword</a><br>
        Delete the password from store.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgeupdate">update</a><br>
        Login if needed and update all locations, rooms and appliances.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgeclearreadings">clearreadings</a><br>
        Clear all readings of the module.
      </li>
      <br>
      <b><i>Debug-mode</i></b><br>
      <br>
      <li><a name="GroheOndusSmartBridgedebugGetDevicesState">debugGetDevicesState</a><br>
        If debug-mode is enabled:<br>
        get locations, rooms and appliances.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedebugLogin">debugLogin</a><br>
        If debug-mode is enabled:<br>
        login.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedebugSetLoginState">debugSetLoginState</a><br>
        If debug-mode is enabled:<br>
        set/reset internal statemachine to/from state "login" - if set all actions will be locked!.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedebugSetTokenExpired">debugSetTokenExpired</a><br>
        If debug-mode is enabled:<br>
        set the expiration timestamp of the login-token to now - next action will trigger a login.
      </li>
    </ul>
    <br>
    <a name="GroheOndusSmartBridgeattr"></a><b>Attributes</b><br>
    <ul>
      <li><a name="GroheOndusSmartBridgegroheOndusAccountEmail">groheOndusAccountEmail</a><br>
        Your registered Email-address to login to the grohe cloud.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgeautocreatedevices">autocreatedevices</a><br>
        If <b>enabled</b> (default) then GroheOndusSmartDevices will be created automatically.<br>
        If <b>disabled</b> then GroheOndusSmartDevices must be create manually.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgeinterval">interval</a><br>
        Interval in seconds to poll for locations, rooms and appliances.
        The default value is 60 seconds.
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedisable">disable</a><br>
        If <b>0</b> (default) then GroheOndusSmartBridge is <b>enabled</b>.<br>
        If <b>1</b> then GroheOndusSmartBridge is <b>disabled</b> - no communication to the grohe cloud will be done.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedebug">debug</a><br>
        If <b>0</b> (default) debugging mode is <b>disabled</b>.<br>
        If <b>1</b> debugging mode is <b>enabled</b> - more internals and commands are shown.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartBridgedebugJSON">debugJSON</a><br>
        If <b>0</b> (default)<br>
        If <b>1</b> if communication fails the json-payload of incoming telegrams is set to a reading.<br>
      </li>
    </ul><br>
    <a name="GroheOndusSmartBridgereadings"></a><b>Readings</b>
    <ul>
      <li><a>count_appliance</a><br>
        Count of appliances.<br>
      </li>
      <br>
      <li><a>count_locations</a><br>
        Count of locations.<br>
      </li>
      <br>
      <li><a>count_rooms</a><br>
        Count of rooms.<br>
      </li>
    </ul><br>
    <a name="GroheOndusSmartBridgeinternals"></a><b>Internals</b>
    <ul>
      <li><a>DEBUG_IsDisabled</a><br>
        If <b>1</b> (default)<br>
        If <b>0</b> debugging mode is enabled - more internals and commands are shown.<br>
      </li>
    </ul><br>
    <br>
  </ul>
=end html

=for :application/json;q=META.json 73_GroheOndusSmartBridge.pm
{
  "abstract": "Modul to communicate with the GroheCloud",
  "x_lang": {
    "de": {
      "abstract": "Modul zur Daten√ºbertragung zur GroheCloud"
    }
  },
  "keywords": [
    "fhem-mod-device",
    "fhem-core",
    "Grohe",
    "Smart"
  ],
  "release_status": "stable",
  "license": "GPL_2",
  "author": [
    "J0EK3R <J0EK3R@gmx.net>"
  ],
  "x_fhem_maintainer": [
    "J0EK3R"
  ],
  "x_fhem_maintainer_github": [
    "J0EK3R@gmx.net"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.016, 
        "Meta": 0,
        "HTML::Entities": 0,
        "JSON": 0
      },
      "recommends": {
      },
      "suggests": {
      }
    }
  }
}
=end :application/json;q=META.json

=cut
