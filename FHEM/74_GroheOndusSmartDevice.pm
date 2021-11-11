###############################################################################
#
# Developed with eclipse
#
#  (c) 2019 Copyright: J.K. (J0EK3R at gmx dot net)
#  All rights reserved
#
#   Special thanks goes to comitters:
#
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
# $Id: 74_GroheOndusSmartDevice.pm 201 2020-04-04 06:14:00Z J0EK3R $
#
###############################################################################

my $VERSION = '3.0.11';

package main;

use strict;
use warnings;

my $missingModul = "";

use FHEM::Meta;
use Time::Local;
use Time::HiRes qw(gettimeofday);
eval {use JSON;1 or $missingModul .= 'JSON '};

#########################
# Forward declaration
sub GroheOndusSmartDevice_Initialize($);
sub GroheOndusSmartDevice_Define($$);
sub GroheOndusSmartDevice_Undef($$);
sub GroheOndusSmartDevice_Delete($$);
sub GroheOndusSmartDevice_Attr(@);
sub GroheOndusSmartDevice_Notify($$);
sub GroheOndusSmartDevice_Set($@);
sub GroheOndusSmartDevice_Parse($$);

sub GroheOndusSmartDevice_Upgrade($);
sub GroheOndusSmartDevice_Debug_Update($);

sub GroheOndusSmartDevice_TimerExecute($);
sub GroheOndusSmartDevice_TimerRemove($);

sub GroheOndusSmartDevice_IOWrite($$);

sub GroheOndusSmartDevice_SenseGuard_Update($);
sub GroheOndusSmartDevice_SenseGuard_GetState($;$$);
sub GroheOndusSmartDevice_SenseGuard_GetConfig($;$$);
sub GroheOndusSmartDevice_SenseGuard_GetData($;$$);
sub GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($);
sub GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($;$$);
sub GroheOndusSmartDevice_SenseGuard_Set($@);

sub GroheOndusSmartDevice_Sense_Update($);
sub GroheOndusSmartDevice_Sense_GetState($;$$);
sub GroheOndusSmartDevice_Sense_GetConfig($;$$);
sub GroheOndusSmartDevice_Sense_GetData($;$$);
sub GroheOndusSmartDevice_Sense_Set($@);

sub GroheOndusSmartDevice_GetGMTOffset();
sub GroheOndusSmartDevice_GetGMTMidnightDate();

my $SenseGuard_DefaultInterval = 60; # default value for the polling interval in seconds
my $Sense_DefaultInterval = 600;     # default value for the polling interval in seconds

my $SenseGuard_DefaultStateFormat =  "State: state<br/>Valve: CmdValveState<br/>Consumption: TodayWaterConsumption l<br/>Temperature: LastTemperature Grad C<br/>Pressure: LastPressure bar";
my $SenseGuard_DefaultWebCmdFormat = "update:valve on:valve off";

my $Sense_DefaultStateFormat =       "State: state<br/>Temperature: LastTemperature Grad C<br/>Humidity: LastHumidity %";
my $Sense_DefaultWebCmdFormat =      "update";

my $TimeStampFormat = '%Y-%m-%dT%I:%M:%S';

# AttributeList for all types of GroheOndusSmartDevice 
my $GroheOndusSmartDevice_AttrList = 
    "debug:0,1 " . 
    "debugJSON:0,1 " . 
    "disable:0,1 " . 
    "interval ";

# AttributeList with deprecated attributes
my $GroheOndusSmartDevice_AttrList_Deprecated = 
    "model:sense,sense_guard " . 
    "IODev "; 

# AttributeList for SenseGuard
my $GroheOndusSmartDevice_SenseGuard_AttrList = 
    $GroheOndusSmartDevice_AttrList .
    "offsetEnergyCost " . 
    "offsetWaterCost " . 
    "offsetWaterConsumption " . 
    "offsetHotWaterShare "; 

# AttributeList for Sense
my $GroheOndusSmartDevice_Sense_AttrList = 
    $GroheOndusSmartDevice_AttrList .
    ""; 

# AttributeList with all Attributes for module init
my $GroheOndusSmartDevice_AttrList_Init = 
    $GroheOndusSmartDevice_AttrList_Deprecated .
    $GroheOndusSmartDevice_SenseGuard_AttrList .
    $GroheOndusSmartDevice_Sense_AttrList; 

# AttributeList with all Attributes except deprecated for Upgrade
my $GroheOndusSmartDevice_AttrList_Upgrade = 
    $GroheOndusSmartDevice_SenseGuard_AttrList .
    $GroheOndusSmartDevice_Sense_AttrList; 

# global Reference to module definition hash
my $GroheOndusSmartDeviceDefinition;

#####################################
sub GroheOndusSmartDevice_Initialize($)
{
  my ($hash) = @_;

  $GroheOndusSmartDeviceDefinition = $hash;

  # Provider
  $hash->{Match} = '^GROHEONDUSSMARTDEVICE_.*';

  # Consumer
  $hash->{SetFn}    = \&GroheOndusSmartDevice_Set;
  $hash->{DefFn}    = \&GroheOndusSmartDevice_Define;
  $hash->{UndefFn}  = \&GroheOndusSmartDevice_Undef;
  $hash->{DeleteFn} = \&GroheOndusSmartDevice_Delete;
  $hash->{ParseFn}  = \&GroheOndusSmartDevice_Parse;
  $hash->{NotifyFn} = \&GroheOndusSmartDevice_Notify;

  $hash->{AttrFn}   = \&GroheOndusSmartDevice_Attr;
  
  # list aof attributes has changed from v2 -> v3
  # -> the redefinition is done automatically
  # old attribute list is set to be able to get the deprecated attribute values
  # on global event "INITIALIZED" the new attribute list is set 
  $hash->{AttrList} = 
    $GroheOndusSmartDevice_AttrList_Init . 
    $readingFnAttributes;

  foreach my $d ( sort keys %{ $modules{GroheOndusSmartDevice}{defptr} } )
  {
    my $hash = $modules{GroheOndusSmartDevice}{defptr}{$d};
    $hash->{VERSION} = $VERSION;
  }

  return FHEM::Meta::InitMod( __FILE__, $hash );
}

#####################################
# Define( $hash, $def)
sub GroheOndusSmartDevice_Define($$)
{
  my ( $hash, $def ) = @_;
  my @a = split( "[ \t]+", $def );

  return $@
    unless ( FHEM::Meta::SetInternals($hash) );

  return "Cannot define GroheOndus Bridge device. Perl modul $missingModul is missing."
    if ($missingModul);

  my $name;
  my $bridge = undef;
  my $deviceId;
  my $model;

  # old definition format
  if(@a == 4)
  {
    $name     = $a[0];
    $deviceId = $a[2];
    $model    = $a[3];
    
    CommandAttr( undef, "$name IODev $modules{GroheOndusSmartBridge}{defptr}{BRIDGE}->{NAME}" )
      if ( AttrVal( $name, 'IODev', 'none' ) eq 'none' );

    $bridge = AttrVal( $name, 'IODev', 'none' );
    
    $hash->{DEF} = "$bridge $deviceId $model";
  }
  elsif(@a == 5)
  {
    $name     = $a[0];
    $bridge   = $a[2];
    $deviceId = $a[3];
    $model    = $a[4];
  }
  else
  {
    return "wrong number of parameters: define <NAME> GroheOndusSmartDevice <bridge> <deviceId> <model>"
  }

  $hash->{DEVICEID}              = $deviceId;
  $hash->{MODEL}                 = $model;
  $hash->{VERSION}               = $VERSION;
  $hash->{NOTIFYDEV}             = "global,$name,$bridge";
  $hash->{RETRIES}               = 3;
  $hash->{helper}{DEBUG}         = '0';
  $hash->{helper}{IsDisabled}    = '0';
  
  # set model depending defaults
  ### sense_guard
  if ( $model eq 'sense_guard' )
  {
    # the SenseGuard devices update every 15 minutes
    $hash->{'.DEFAULTINTERVAL'} = $SenseGuard_DefaultInterval;
    
    $hash->{INTERVAL} = $hash->{'.DEFAULTINTERVAL'};

    $hash->{helper}{TELEGRAM_CONFIGCOUNTER}  = 0;
    $hash->{helper}{TELEGRAM_STATUSCOUNTER}  = 0;
    $hash->{helper}{TELEGRAM_DATACOUNTER}    = 0;
    $hash->{helper}{TELEGRAM_COMMANDCOUNTER} = 0;

    # overrides the shown AttributeList of module-definition
    addToDevAttrList($name, $GroheOndusSmartDevice_SenseGuard_AttrList);

    CommandAttr( undef, $name . ' stateFormat ' . $SenseGuard_DefaultStateFormat )
      if ( AttrVal( $name, 'stateFormat', 'none' ) eq 'none' );

    CommandAttr( undef, $name . ' webCmd ' . $SenseGuard_DefaultWebCmdFormat )
      if ( AttrVal( $name, 'webCmd', 'none' ) eq 'none' );
  }
  ### sense
  elsif ( $model eq 'sense' )
  {
    # the Sense devices update just once a day
    $hash->{'.DEFAULTINTERVAL'} = $Sense_DefaultInterval;

    $hash->{INTERVAL} = $hash->{'.DEFAULTINTERVAL'};

    $hash->{helper}{TELEGRAM_CONFIGCOUNTER} = 0;
    $hash->{helper}{TELEGRAM_STATUSCOUNTER} = 0;
    $hash->{helper}{TELEGRAM_DATACOUNTER}   = 0;

    # overrides the shown AttributeList of module-definition
    addToDevAttrList($name, $GroheOndusSmartDevice_Sense_AttrList);

    CommandAttr( undef, $name . ' stateFormat ' . $Sense_DefaultStateFormat )
      if ( AttrVal( $name, 'stateFormat', 'none' ) eq 'none' );

    CommandAttr( undef, $name . ' webCmd ' . $Sense_DefaultWebCmdFormat )
      if ( AttrVal( $name, 'webCmd', 'none' ) eq 'none' );
  }
  else
  {
    return "unknown model $model"
  }

  AssignIoPort( $hash, $bridge );

  my $iodev = $hash->{IODev}->{NAME};

  my $d = $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

  return "GroheOndusSmartDevice device $name on GroheOndusSmartBridge $iodev already defined."
    if (defined($d) and 
      $d->{IODev} == $hash->{IODev} and 
      $d->{NAME} ne $name );

  # ensure attribute room is present
  if ( AttrVal( $name, 'room', 'none' ) eq 'none' )
  {
    my $room = AttrVal( $iodev, 'room', 'GroheOndusSmart' );
    CommandAttr( undef, $name . ' room ' . $room );
  }
  
  # ensure attribute inerval is present
  CommandAttr( undef, $name . ' interval ' . $hash->{INTERVAL} )
    if ( AttrVal( $name, 'interval', 'none' ) eq 'none' );

  Log3 $name, 3, "GroheOndusSmartDevice ($name) - defined GroheOndusSmartDevice with DEVICEID: $deviceId";

  readingsSingleUpdate( $hash, 'state', 'initialized', 1 );

  $modules{GroheOndusSmartDevice}{defptr}{$deviceId} = $hash;

  return undef;
}

#####################################
# Undef( $hash, $arg )
sub GroheOndusSmartDevice_Undef($$)
{
  my ( $hash, $arg ) = @_;
  my $name     = $hash->{NAME};
  my $deviceId = $hash->{DEVICEID};

  GroheOndusSmartDevice_TimerRemove($hash);

  delete $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

  return undef;
}

#####################################
# Delete( $hash, $name )
sub GroheOndusSmartDevice_Delete($$)
{
  my ( $hash, $name ) = @_;

  return undef;
}

#####################################
sub GroheOndusSmartDevice_Attr(@)
{
  my ( $cmd, $name, $attrName, $attrVal ) = @_;
  my $hash = $defs{$name};

  Log3 $name, 4, "GroheOndusSmartDevice_Attr($name) - Attr was called";

  # Attribute "disable"
  if ( $attrName eq 'disable' )
  {
    if ( $cmd eq 'set' and 
      $attrVal eq '1' )
    {
      $hash->{helper}{IsDisabled} = '1';

      GroheOndusSmartDevice_TimerRemove($hash);
    
      readingsSingleUpdate( $hash, 'state', 'inactive', 1 );
      Log3 $name, 3, "GroheOndusSmartDevice ($name) - disabled";
    } 
    else #elsif ( $cmd eq 'del' )
    {
      $hash->{helper}{IsDisabled} = '0';

      readingsSingleUpdate( $hash, 'state', 'active', 1 );

      GroheOndusSmartDevice_TimerExecute( $hash );
      Log3 $name, 3, "GroheOndusSmartDevice ($name) - enabled";
    }
  }

  # Attribute "interval"
  elsif ( $attrName eq 'interval' )
  {
    # onchange event for attribute "interval" is handled in sub "Notify" -> calls "updateValues" -> Timer is reloaded
    if ( $cmd eq 'set' )
    {
      return 'Interval must be greater than 0'
        unless ( $attrVal > 0 );

      GroheOndusSmartDevice_TimerRemove($hash);
    
      $hash->{INTERVAL} = $attrVal;

      GroheOndusSmartDevice_TimerExecute( $hash );

      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - set interval: $attrVal";
    } 
    elsif ( $cmd eq 'del' )
    {
      GroheOndusSmartDevice_TimerRemove($hash);
    
    $hash->{INTERVAL} = $hash->{'.DEFAULTINTERVAL'};

      GroheOndusSmartDevice_TimerExecute( $hash );

      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - delete User interval and set default: 60";
    }
  }

  # Attribute "debug"
  elsif ( $attrName eq 'debug' )
  {
    if ( $cmd eq 'set')
    {
      Log3 $name, 3, "GroheOndusSmartBridge_Attr($name) - debugging enabled";

      $hash->{helper}{DEBUG} = "$attrVal";
      GroheOndusSmartDevice_Debug_Update($hash);
    } 
    elsif ( $cmd eq 'del' )
    {
      Log3 $name, 3, "GroheOndusSmartBridge_Attr($name) - debugging disabled";

      $hash->{helper}{DEBUG} = '0';
      GroheOndusSmartDevice_Debug_Update($hash);
    }
  }

  # Attribute "offsetWaterCost"
  elsif ( $attrName eq 'offsetWaterCost' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetWaterCost: $attrVal";
      
    } 
    elsif ( $cmd eq 'del' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - delete User offsetWaterCost and set default: 0";
    }
    
    GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($hash)
      if($init_done);
  }
  
  # Attribute "offsetHotWaterShare"
  elsif ( $attrName eq 'offsetHotWaterShare' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetHotWaterShare: $attrVal";
      
    } 
    elsif ( $cmd eq 'del' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - delete User offsetHotWaterShare and set default: 0";
    }
    
    GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($hash)
      if($init_done); 
  }
  
  # Attribute "offsetEnergyCost"
  elsif ( $attrName eq 'offsetEnergyCost' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetEnergyCost: $attrVal";
      
    } 
    elsif ( $cmd eq 'del' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - delete User offsetEnergyCost and set default: 0";
    }
    
    GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($hash)
      if($init_done);
  }
  
  # Attribute "offsetWaterConsumption"
  elsif ( $attrName eq 'offsetWaterConsumption' )
  {
    if ( $cmd eq 'set' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetWaterConsumption: $attrVal";
      
    } 
    elsif ( $cmd eq 'del' )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Attr($name) - delete User offsetWaterConsumption and set default: 0";
    }
    
    GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($hash)
      if($init_done);
  }
  
  return undef;
}

#####################################
sub GroheOndusSmartDevice_Notify($$)
{
  my ( $hash, $dev ) = @_;
  my $name = $hash->{NAME};

  return
    if ( $hash->{helper}{IsDisabled} ne '0' );

  my $devname = $dev->{NAME};
  my $devtype = $dev->{TYPE};
  my $events  = deviceEvents( $dev, 1 );

  return
    if ( !$events );

  Log3 $name, 4, "GroheOndusSmartDevice_Notify($name) - DevType: \'$devtype\'";

  # process 'global' events
  if ( $devtype eq 'Global' )
  {
    # global Initialization is done
    if( grep /^INITIALIZED$/, @{$events} )
    {
      Log3 $name, 3, "GroheOndusSmartDevice_Notify($name) - global event INITIALIZED was catched";

      GroheOndusSmartDevice_Upgrade($hash);
    }

    if( $init_done )
    {
    }
  }
  
  # process events from Bridge
  elsif ( $devtype eq 'GroheOndusSmartBridge' )
  {
    if ( grep /^state:.*$/, @{$events} )
    {
      my $ioDeviceState =  ReadingsVal($hash->{IODev}->{NAME}, 'state', 'none');
      Log3 $name, 4, "GroheOndusSmartDevice_Notify($name) - event \'state: $ioDeviceState\' from GroheOndusSmartBridge was catched";

      if ( $ioDeviceState eq 'connected to cloud' )
      {
      }
      else
      {
        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged( $hash, 'state', 'bridge ' . $ioDeviceState, 1 );
        readingsEndUpdate( $hash, 1 );
      }
    }
    else
    {
      Log3 $name, 4, "GroheOndusSmartDevice_Notify($name) - event from GroheOndusSmartBridge was catched";
    }
  }
  
  # process internal events
  elsif ( $devtype eq 'GroheOndusSmartDevice' )
  {
  }

  return;
}

#####################################
sub GroheOndusSmartDevice_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  my $payload;
#  my $model = AttrVal( $name, 'model', 'unknown' );
  my $model = $hash->{MODEL};

  Log3 $name, 4, "GroheOndusSmartDevice_Set($name): cmd= $cmd";

  #########################################################
  ### sense_guard #########################################
  #########################################################
  if ( $model eq 'sense_guard' )
  {
    return GroheOndusSmartDevice_SenseGuard_Set($hash, $name, $cmd, @args);
  }
  #########################################################
  ### sense ###############################################
  #########################################################
  elsif ( $model eq 'sense' )
  {
    return GroheOndusSmartDevice_Sense_Set($hash, $name, $cmd, @args);
  }
  ### unknown ###
  else
  {
    return "Unknown model '$model'";
  }
}

#####################################
# This methode parses the given json string.
# If there is a defined GroheOndusSmartDevice module then the json-structure
# is passed to the methode WriteReadings.
# Else a new GroheOndusSmartDevice module is created.
sub GroheOndusSmartDevice_Parse($$)
{
  my ( $io_hash, $match ) = @_;
  my $io_name = $io_hash->{NAME};

  # to pass parameters to this underlying logical device
  # the hash 'currentAppliance' is set in io_hash for the moment
  my $current_appliance_id = $io_hash->{currentAppliance}->{appliance_id};
  my $current_type_id = $io_hash->{currentAppliance}->{type_id};
  my $current_name = $io_hash->{currentAppliance}->{name};
  my $current_location_id = $io_hash->{currentAppliance}->{location_id};
  my $current_room_id = $io_hash->{currentAppliance}->{room_id};

  Log3 $io_name, 4, "GroheOndusSmartBridge($io_name) -> GroheOndusSmartDevice_Parse";

  if ( defined( $current_appliance_id ) )
  {
    # SmartDevice with $deviceId found:
    if ( my $hash = $modules{GroheOndusSmartDevice}{defptr}{$current_appliance_id} )
    {
      my $name = $hash->{NAME};

      Log3 $name, 5, "GroheOndusSmartDevice_Parse($name) - found logical device";

      # set internals
      $hash->{appliance_id} = $current_appliance_id;
      $hash->{type_id} = $current_type_id;
      $hash->{location_id} = $current_location_id;
      $hash->{room_id} = $current_room_id;

      # change state to "connected to cloud" -> Notify -> load timer
      readingsBeginUpdate($hash);
      readingsBulkUpdateIfChanged( $hash, 'state', 'connected over bridge to cloud', 1 );
      readingsEndUpdate( $hash, 1 );

      # if not timer is running then start one
      if( not defined( $hash->{NEXTTIMER} ) or
        $hash->{NEXTTIMER} eq "none")
      {
        GroheOndusSmartDevice_TimerExecute( $hash );
      }

      return $name;
    }

    # SmartDevice not found, create new one
    else
    {
      my $deviceName = makeDeviceName( $current_name );
      
      if ( $current_type_id == 101 )
      {
        my $deviceTypeName = 'sense';
        Log3 $io_name, 3, "GroheOndusSmartBridge($io_name) -> autocreate new device $deviceName with applianceId $current_appliance_id, model $deviceTypeName";

        return "UNDEFINED $deviceName GroheOndusSmartDevice $io_name $current_appliance_id $deviceTypeName";
      } 
      elsif ( $current_type_id == 103 )
      {
        my $deviceTypeName = 'sense_guard';
        Log3 $io_name, 3, "GroheOndusSmartBridge($io_name) -> autocreate new device $deviceName with applianceId $current_appliance_id, model $deviceTypeName";

        return "UNDEFINED $deviceName GroheOndusSmartDevice $io_name $current_appliance_id $deviceTypeName";
      } 
      else
      {
        Log3 $io_name, 3, "GroheOndusSmartBridge($io_name) - can't find matching devicetype";

        return undef;
      }
    }
  }
}

##################################
sub GroheOndusSmartDevice_Upgrade($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  my $newAttrList = $GroheOndusSmartDevice_AttrList_Upgrade . $readingFnAttributes;
  
  if($GroheOndusSmartDeviceDefinition->{AttrList} ne $newAttrList)
  {
    Log3 $name, 3, "GroheOndusSmartDevice_Upgrade($name) - patching GroheOndusSmartDevice.AttrList";
    # change list of attributes
    $GroheOndusSmartDeviceDefinition->{AttrList} = $newAttrList;
  } 

  if ( AttrVal( $name, 'IODev', 'none' ) ne 'none' )
  {
    Log3 $name, 3, "GroheOndusSmartDevice_Upgrade($name) - deleting old attribute IODEV";
    fhem("deleteattr $name IODev", 1);
  }

  if ( AttrVal( $name, 'model', 'none' ) ne 'none' )
  {
    Log3 $name, 3, "GroheOndusSmartDevice_Upgrade($name) - deleting old attribute model";
    fhem("deleteattr $name model", 1);
  }
}

#####################################
#
sub GroheOndusSmartDevice_Debug_Update($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 5, "GroheOndusSmartDevice_Debug_Update($name)";
  
  if( $hash->{helper}{DEBUG} eq '1')
  {
    $hash->{DEBUG_IsDisabled} = $hash->{helper}{IsDisabled};
    
    my @retrystring_keys =  grep /TELEGRAM_/, keys %{$hash->{helper}};
    foreach (@retrystring_keys)
    {
      $hash->{'DEBUG_' . $_} = $hash->{helper}{$_};
    }

  }
  else
  {
    # delete all keys starting with 'DEBUG_'
    my @matching_keys =  grep /DEBUG_/, keys %$hash;
    foreach (@matching_keys)
    {
      delete $hash->{$_};
    }
  }
}

##################################
sub GroheOndusSmartDevice_TimerExecute($)
{
  my $hash     = shift;
  my $name     = $hash->{NAME};
  my $interval = $hash->{INTERVAL};
  my $model = $hash->{MODEL};

  GroheOndusSmartDevice_TimerRemove($hash);

  if ( $init_done and 
    $hash->{helper}{IsDisabled} eq '0' )
  {
    Log3 $name, 4, "GroheOndusSmartDevice_TimerExecute($name)";

    ### sense ###
    if ( $model eq 'sense' )
    {
      GroheOndusSmartDevice_Sense_Update($hash);
    }
    ### sense_guard ###
    elsif ( $model eq 'sense_guard' )
    {
      GroheOndusSmartDevice_SenseGuard_Update($hash);
    }

    # reload timer
    my $nextTimer = gettimeofday() + $interval;
    $hash->{NEXTTIMER} = strftime($TimeStampFormat, localtime($nextTimer));
    InternalTimer( $nextTimer, \&GroheOndusSmartDevice_TimerExecute, $hash );
  } 
  else
  {
    readingsSingleUpdate( $hash, 'state', 'disabled', 1 );

    Log3 $name, 4, "GroheOndusSmartDevice_TimerExecute($name) - device is disabled";
  }
}

##################################
sub GroheOndusSmartDevice_TimerRemove($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "GroheOndusSmartDevice_TimerRemove($name)";

  $hash->{NEXTTIMER} = "none";
  RemoveInternalTimer($hash, \&GroheOndusSmartDevice_TimerExecute);
}

##################################
sub GroheOndusSmartDevice_IOWrite($$)
{
  my ( $hash, $param ) = @_;
  my $name = $hash->{NAME};

  Log3 $name, 4, "GroheOndusSmartDevice_IOWrite($name)";

  IOWrite( $hash, $param );
}

##################################
sub GroheOndusSmartDevice_SenseGuard_Update($)
{
  my ( $hash ) = @_;
  my $name     = $hash->{NAME};

  Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_Update($name)";

  # paralleles Abrufen!
  #GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($hash);
  #GroheOndusSmartDevice_SenseGuard_GetData($hash);
  #GroheOndusSmartDevice_SenseGuard_GetState($hash);
  #GroheOndusSmartDevice_SenseGuard_GetConfig($hash);
  
  # serielles Abrufen
  my $getApplianceCommand = sub { GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($hash); };
  my $getData = sub { GroheOndusSmartDevice_SenseGuard_GetData($hash, $getApplianceCommand); };
  my $getState = sub { GroheOndusSmartDevice_SenseGuard_GetState($hash, $getData); };
  my $getConfig = sub { GroheOndusSmartDevice_SenseGuard_GetConfig($hash, $getState); };
  
  $getConfig->();
}

##################################
sub GroheOndusSmartDevice_SenseGuard_GetState($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_STATUSIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - resultCallback";

    if ( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };

      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_SenseGuard_GetState($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETSTATE_JSON_ERROR";
      }
      else
      {
        # Status:
        # {
        #   [
        #     {
        #       "type":"update_available",
        #       "value":0
        #     },
        #     {
        #       "type":"connection",
        #       "value":1
        #     }
        #   ]
        # }
        if ( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          readingsBeginUpdate($hash);

          foreach my $currentData ( @{ $decode_json } )
          {
            if ( $currentData->{type} eq "update_available"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateUpdateAvailable", $currentData->{value} );
            } 
            elsif ( $currentData->{type} eq "connection"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateConnection", $currentData->{value} );
            } 
            elsif ( $currentData->{type} eq "wifi_quality"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateWifiQuality", $currentData->{value} );
            } 
            else
            {
              # write json string to reading "unknown"
              readingsBulkUpdateIfChanged( $hash, "State_unknown-data", encode_json($currentData) );
            }
          }

          readingsEndUpdate( $hash, 1 );

          $hash->{helper}{TELEGRAM_STATUSCOUNTER}++;
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    GroheOndusSmartDevice_Debug_Update($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );
    	
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId . '/status';
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    
    $hash->{helper}{TELEGRAM_STATUSIOWRITE} = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - callbackFail";
      $callbackFail->();
    }
  }
}

##################################
sub GroheOndusSmartDevice_SenseGuard_GetConfig($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_CONFIGCIOALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - resultCallback";

    if( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETCONFIG_JSON_ERROR";
      }
      else
      {
      # [
      #   {
      #     "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      #     "installation_date":"2019-01-30T06:32:37.000+00:00",
      #     "name":"KG Vorratsraum SenseGUARD",
      #     "serial_number":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      #     "type":103,
      #     "version":"01.44.Z22.0400.0101",
      #     "tdt":"2021-10-09T06:35:25.000+02:00",
      #     "timezone":60,
      #     "role":"owner",
      #     "registration_complete":true,
      #     "calculate_average_since":"2019-01-30T06:32:37.000Z",
      #     "snooze_status":"NON_EXISTENT",
      #     "config":
      #     {
      #       "measurement_period":900,
      #       "measurement_transmission_intervall":900,
      #       "measurement_transmission_intervall_offset":1,
      #       "action_on_major_leakage":1,
      #       "action_on_minor_leakage":0,
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
      #       "action_on_btw_0_1_and_0_8_leakage":0,
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
      #       "sprinkler_mode_active_sunday":false,
      #       "thresholds":
      #       [
      #         {
      #           "quantity":"flowrate",
      #           "type":"min",
      #            "value":3,
      #            "enabled":false
      #         },
      #         {
      #           "quantity":"flowrate",
      #           "type":"max",
      #           "value":50,
      #           "enabled":true
      #         },
      #         {
      #           "quantity":"pressure",
      #           "type":"min",
      #           "value":2,
      #           "enabled":false
      #         },
      #         {
      #           "quantity":"pressure",
      #           "type":"max",
      #           "value":8,
      #           "enabled":false
      #         },
      #         {
      #           "quantity":"temperature_guard",
      #           "type":"min",
      #           "value":5,
      #           "enabled":false
      #         },
      #         {
      #           "quantity":"temperature_guard",
      #           "type":"max",
      #           "value":45,
      #           "enabled":false
      #         }
      #       ]
      #     }
      #   }
      # ]
      
        if ( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          readingsBeginUpdate($hash);

          #     "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
          #     "installation_date":"2019-01-30T06:32:37.000+00:00",
          #     "name":"KG Vorratsraum SenseGUARD",
          #     "serial_number":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          #     "type":103,
          #     "version":"01.44.Z22.0400.0101",
          #     "tdt":"2021-10-09T06:35:25.000+02:00",
          #     "timezone":60,
          #     "role":"owner",
          #     "registration_complete":true,
          #     "calculate_average_since":"2019-01-30T06:32:37.000Z",
          #     "snooze_status":"NON_EXISTENT",

          my $currentEntry = $decode_json->[0];

          if ( defined( $currentEntry )
            and ref( $currentEntry ) eq "HASH" )
          {
            readingsBulkUpdateIfChanged( $hash, "ApplianceID", "$currentEntry->{appliance_id}" )
              if( defined( $currentEntry->{appliance_id} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceInstallationDate", "$currentEntry->{installation_date}" )
              if( defined( $currentEntry->{installation_date} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceName", "$currentEntry->{name}" )
              if( defined( $currentEntry->{name} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceSerialNumber", "$currentEntry->{serial_number}" )
              if( defined( $currentEntry->{serial_number} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceType", "$currentEntry->{type}" )
              if( defined( $currentEntry->{type} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceVersion", "$currentEntry->{version}" )
              if( defined( $currentEntry->{version} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceTDT", "$currentEntry->{tdt}" )
              if( defined( $currentEntry->{tdt} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceTimezone", "$currentEntry->{timezone}" )
              if( defined( $currentEntry->{timezone} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceRole", "$currentEntry->{role}" )
              if( defined( $currentEntry->{role} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceRegistrationComplete", "$currentEntry->{registration_complete}" )
              if( defined( $currentEntry->{registration_complete} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceCalculateAverageSince", "$currentEntry->{calculate_average_since}" )
              if( defined( $currentEntry->{calculate_average_since} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceSnoozeStatus", "$currentEntry->{snooze_status}" )
              if( defined( $currentEntry->{snooze_status} ) );

            #       "measurement_period":900,
            #       "measurement_transmission_intervall":900,
            #       "measurement_transmission_intervall_offset":1,
            #       "action_on_major_leakage":1,
            #       "action_on_minor_leakage":0,
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
            #       "action_on_btw_0_1_and_0_8_leakage":0,
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
            #       "sprinkler_mode_active_sunday":false,
            my $currentConfig = $currentEntry->{config};

            if ( defined( $currentConfig )
              and ref( $currentConfig ) eq "HASH" )
            {
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementPeriod", "$currentConfig->{measurement_period}" )
                if( defined( $currentConfig->{measurement_period} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementTransmissionInterval", "$currentConfig->{measurement_transmission_intervall}" )
                if( defined( $currentConfig->{measurement_transmission_intervall} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementTransmissionIntervalOffset", "$currentConfig->{measurement_transmission_intervall_offset}" )
                if( defined( $currentConfig->{measurement_transmission_intervall_offset} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementDetectionInterval", "$currentConfig->{detection_interval}" )
                if( defined( $currentConfig->{detection_interval} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementImpulseIgnore", "$currentConfig->{impulse_ignore}" )
                if( defined( $currentConfig->{impulse_ignore} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementTimeIgnore", "$currentConfig->{time_ignore}" )
                if( defined( $currentConfig->{time_ignore} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementDetectionTime", "$currentConfig->{detection_time}" )
                if( defined( $currentConfig->{detection_time} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigMeasurementSystemErrorMonitor", "$currentConfig->{monitor_system_error}" )
                if( defined( $currentConfig->{monitor_system_error} ) );

              # Withdrawel
              readingsBulkUpdateIfChanged( $hash, "ConfigWithdrawelAmountLimit", "$currentConfig->{withdrawel_amount_limit}" )
                if( defined( $currentConfig->{withdrawel_amount_limit} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigWithdrawelAmountLimitBreachMonitor", "$currentConfig->{monitor_withdrawel_amount_limit_breach}" )
                if( defined( $currentConfig->{monitor_withdrawel_amount_limit_breach} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigWithdrawelAmountLimitBreachAction", "$currentConfig->{action_on_withdrawel_amount_limit_breach}" )
                if( defined( $currentConfig->{action_on_withdrawel_amount_limit_breach} ) );

              # Flowrate
              readingsBulkUpdateIfChanged( $hash, "ConfigFlowrateLimitLowerMonitor", "$currentConfig->{monitor_lower_flow_limit}" )
                if( defined( $currentConfig->{monitor_lower_flow_limit} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigFlowrateLimitUpperMonitor", "$currentConfig->{monitor_upper_flow_limit}" )
                if( defined( $currentConfig->{monitor_upper_flow_limit} ) );

              # Pressure
              readingsBulkUpdateIfChanged( $hash, "ConfigPressureLimitLowerMonitor", "$currentConfig->{monitor_lower_pressure_limit}" )
                if( defined( $currentConfig->{monitor_lower_pressure_limit} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigPressureLimitUpperMonitor", "$currentConfig->{monitor_upper_pressure_limit}" )
                if( defined( $currentConfig->{monitor_upper_pressure_limit} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigPressureToleranceBand", "$currentConfig->{pressure_tolerance_band}" )
                if( defined( $currentConfig->{pressure_tolerance_band} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigPressureDrop", "$currentConfig->{pressure_drop}" )
                if( defined( $currentConfig->{pressure_drop} ) );

              # Temperature
              readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureFrostAlertMonitor", "$currentConfig->{monitor_frost_alert}" )
                if( defined( $currentConfig->{monitor_frost_alert} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureLimitLowerMonitor", "$currentConfig->{monitor_lower_temperature_limit}" )
                if( defined( $currentConfig->{monitor_lower_temperature_limit} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureLimitUpperMonitor", "$currentConfig->{monitor_upper_temperature_limit}" )
                if( defined( $currentConfig->{monitor_upper_temperature_limit} ) );

              # Leakage
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageMajorMonitor", "$currentConfig->{monitor_major_leakage}" )
                if( defined( $currentConfig->{monitor_major_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageMajorAction", "$currentConfig->{action_on_major_leakage}" )
                if( defined( $currentConfig->{action_on_major_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageMinorMonitor", "$currentConfig->{monitor_minor_leakage}" )
                if( defined( $currentConfig->{monitor_minor_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageMinorAction", "$currentConfig->{action_on_minor_leakage}" )
                if( defined( $currentConfig->{action_on_minor_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageMicroMonitor", "$currentConfig->{monitor_micro_leakage}" )
                if( defined( $currentConfig->{monitor_micro_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageMicroAction", "$currentConfig->{action_on_micro_leakage}" )
                if( defined( $currentConfig->{action_on_micro_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageBtw01And08Monitor", "$currentConfig->{monitor_btw_0_1_and_0_8_leakage}" )
                if( defined( $currentConfig->{monitor_btw_0_1_and_0_8_leakage} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigLeakageBtw01And08Action", "$currentConfig->{action_on_btw_0_1_and_0_8_leakage}" )
                if( defined( $currentConfig->{action_on_btw_0_1_and_0_8_leakage} ) );

              # SprinklerMode
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeStartTime", "$currentConfig->{sprinkler_mode_start_time}" )
                if( defined( $currentConfig->{sprinkler_mode_start_time} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeStopTime", "$currentConfig->{sprinkler_mode_stop_time}" )
                if( defined( $currentConfig->{sprinkler_mode_stop_time} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveMonday", "$currentConfig->{sprinkler_mode_active_monday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_monday} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveTuesday", "$currentConfig->{sprinkler_mode_active_tuesday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_tuesday} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveWednesday", "$currentConfig->{sprinkler_mode_active_wednesday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_wednesday} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveThursday", "$currentConfig->{sprinkler_mode_active_thursday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_thursday} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveFriday", "$currentConfig->{sprinkler_mode_active_friday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_friday} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveSaturday", "$currentConfig->{sprinkler_mode_active_saturday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_saturday} ) );
              readingsBulkUpdateIfChanged( $hash, "ConfigSprinklerModeActiveSunday", "$currentConfig->{sprinkler_mode_active_sunday}" )
                if( defined( $currentConfig->{sprinkler_mode_active_sunday} ) );

              # "thresholds":
              # [
              #   {
              #     "quantity":"flowrate",
              #     "type":"min",
              #     "value":3,
              #     "enabled":false
              #   },
              #   {
              #     "quantity":"flowrate",
              #     "type":"max",
              #     "value":50,
              #     "enabled":true
              #   },
              #   {
              #     "quantity":"pressure",
              #     "type":"min",
              #     "value":2,
              #     "enabled":false
              #   },
              #   {
              #     "quantity":"pressure",
              #     "type":"max",
              #     "value":8,
              #     "enabled":false
              #   },
              #   {
              #     "quantity":"temperature_guard",
              #     "type":"min",
              #     "value":5,
              #     "enabled":false
              #   },
              #   {
              #     "quantity":"temperature_guard",
              #     "type":"max",
              #     "value":45,
              #     "enabled":false
              #   }
              # ]
              my $currentThresholds = $currentConfig->{thresholds};

              if ( defined( $currentThresholds ) and
                ref( $currentThresholds ) eq "ARRAY" )
              {
                foreach my $currentThreshold ( @{ $currentThresholds} )
                {
                  if ( "$currentThreshold->{quantity}" eq "flowrate" )
                  {
                    if ( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigFlowrateThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif ( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigFlowrateThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  } 
                  elsif ( "$currentThreshold->{quantity}" eq "pressure" )
                  {
                    if ( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigPressureThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif ( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigPressureThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  }
                  elsif ( "$currentThreshold->{quantity}" eq "temperature_guard" )
                  {
                    if ( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif ( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  }
                }
              }
            }
          }
          readingsEndUpdate( $hash, 1 );

          $hash->{helper}{TELEGRAM_CONFIGCOUNTER}++;
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    GroheOndusSmartDevice_Debug_Update($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    
    $hash->{helper}{TELEGRAM_CONFIGIOWRITE} = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - callbackFail";
      $callbackFail->();
    }
  }
}

##################################
sub GroheOndusSmartDevice_SenseGuard_GetData($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_DATAIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - resultCallback";

    if( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_SenseGuard_GetData($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }

        $errorMsg = "GETDATA_JSON_ERROR";
      }
      else
      {
      # Data:
      # {
      #   "data":
      #   {
      #     "measurement":
      #     [
      #       {
      #         "timestamp":"2019-07-14T02:07:36.000+02:00",
      #         "flowrate":0,
      #         "temperature_guard":22.5,
      #         "pressure":3
      #       },
      #       {
      #         "timestamp":"2019-07-14T02:22:36.000+02:00",
      #        "temperature_guard":22.5,
      #         "flowrate":0,
      #         "pressure":3
      #       }
      #     ],
      #     "withdrawals":
      #     [
      #       {
      #         "water_cost":0.01447,
      #         "hotwater_share":0,
      #         "waterconsumption":3.4,
      #         "stoptime":"2019-07-14T03:16:51.000+02:00",
      #         "starttime":"2019-07-14T03:16:24.000+02:00",
      #         "maxflowrate":10.7,
      #         "energy_cost":0
      #       },
      #       {
      #         "waterconsumption":7.6,
      #         "hotwater_share":0,
      #         "energy_cost":0,
      #         "starttime":"2019-07-14T03:58:19.000+02:00",
      #         "stoptime":"2019-07-14T03:59:13.000+02:00",
      #         "maxflowrate":10.9,
      #         "water_cost":0.032346
      #       }
      #     ]
      #   },
      # }
        if ( defined( $decode_json->{data} ) and
          ref( $decode_json->{data} ) eq "HASH" )
        {
          readingsBeginUpdate($hash);

          # Measurement
          #       {
          #         "timestamp":"2019-07-14T02:07:36.000+02:00",
          #         "flowrate":0,
          #         "temperature_guard":22.5,
          #         "pressure":3
          #       },
          if ( defined( $decode_json->{data}->{measurement} ) and
            ref( $decode_json->{data}->{measurement} ) eq "ARRAY" )
          {
            # get entry with latest timestamp
            my $dataTimestamp;
            my $dataFlowrate;
            my $dataTemperature;
            my $dataPressure;

            foreach my $currentData ( @{ $decode_json->{data}->{measurement} } )
            {
              # is this the correct dataset?
              if ( defined( $currentData->{timestamp} ) and
                defined( $currentData->{flowrate} ) and
                defined( $currentData->{temperature_guard} ) and
                defined( $currentData->{pressure} ) )
              {
                # is timestamp newer?
                if ( not defined($dataTimestamp) or
                  $currentData->{timestamp} gt $dataTimestamp )
                {
                  $dataTimestamp   = $currentData->{timestamp};
                  $dataFlowrate    = $currentData->{flowrate};
                  $dataTemperature = $currentData->{temperature_guard};
                  $dataPressure    = $currentData->{pressure};
                }
              }
            }

            readingsBulkUpdateIfChanged( $hash, "LastDataTimestamp", $dataTimestamp )
              if ( defined($dataTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "LastFlowrate", $dataFlowrate )
              if ( defined($dataFlowrate) );
            readingsBulkUpdateIfChanged( $hash, "LastTemperature", $dataTemperature )
              if ( defined($dataTemperature) );
            readingsBulkUpdateIfChanged( $hash, "LastPressure", $dataPressure )
              if ( defined($dataPressure) );
          }

        # withdrawals
        #       {
        #         "water_cost":0.01447,
        #         "hotwater_share":0,
        #         "waterconsumption":3.4,
        #         "stoptime":"2019-07-14T03:16:51.000+02:00",
        #         "starttime":"2019-07-14T03:16:24.000+02:00",
        #         "maxflowrate":10.7,
        #         "energy_cost":0
        #       },
          if ( defined( $decode_json->{data}->{withdrawals} ) and
            ref( $decode_json->{data}->{withdrawals} ) eq "ARRAY" )
          {
            # analysis
            my $dataAnalyzeStartTimestamp;
            my $dataAnalyzeStopTimestamp;
            my $dataAnalyzeCount = 0;

            # get entry with latest timestamp
            my $dataLastStartTimestamp;
            my $dataLastStopTimestamp;
            my $dataLastWaterconsumption;
            my $dataLastMaxflowrate;
            my $dataLastHotwaterShare;
            my $dataLastWaterCost;
            my $dataLastEnergyCost;

            # result of today
            my $dataTodayAnalyzeStartTimestamp;
            my $dataTodayAnalyzeStopTimestamp;
            my $dataTodayAnalyzeCount     = 0;
            my $dataTodayWaterConsumption = 0;
            my $dataTodayMaxflowrate      = 0;
            my $dataTodayHotWaterShare    = 0;
            my $dataTodayWaterCost        = 0;
            my $dataTodayEnergyCost       = 0;

            # get current date
            my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) = localtime( gettimeofday() );
            my $today_ymd    = sprintf( "%04d-%02d-%02d", $year + 1900, $month + 1, $mday );
            my $tomorrow_ymd = sprintf( "%04d-%02d-%02d", $year + 1900, $month + 1, $mday + 1 );    # day > 31 is OK for stringcompare

            # my convention: dataset contains all withdrawals of today
            foreach my $currentData ( @{ $decode_json->{data}->{withdrawals} } )
            {
              # is it the right dataset?
              if ( defined( $currentData->{starttime} ) and
                defined( $currentData->{stoptime} ) and
                defined( $currentData->{waterconsumption} ) and
                defined( $currentData->{maxflowrate} ) and
                defined( $currentData->{hotwater_share} ) and
                defined( $currentData->{water_cost} ) and
                defined( $currentData->{energy_cost} ) )
              {
                $dataAnalyzeCount++;

                # find first timestamp of analysis?
                if ( not defined($dataAnalyzeStartTimestamp) or
                  $currentData->{starttime} lt $dataAnalyzeStartTimestamp )
                {
                  $dataAnalyzeStartTimestamp = $currentData->{starttime};
                }

                # find last timestamp of analysis?
                if ( not defined($dataAnalyzeStopTimestamp) or
                  $currentData->{stoptime} gt $dataAnalyzeStopTimestamp )
                {
                  $dataAnalyzeStopTimestamp = $currentData->{stoptime};
                }

                # is timestamp younger?
                if ( not defined($dataLastStartTimestamp) or
                  $currentData->{starttime} gt $dataLastStartTimestamp )
                {
                  $dataLastStartTimestamp   = $currentData->{starttime};
                  $dataLastStopTimestamp    = $currentData->{stoptime};
                  $dataLastWaterconsumption = $currentData->{waterconsumption};
                  $dataLastMaxflowrate      = $currentData->{maxflowrate};
                  $dataLastHotwaterShare    = $currentData->{hotwater_share};
                  $dataLastWaterCost        = $currentData->{water_cost};
                  $dataLastEnergyCost       = $currentData->{energy_cost};
                }

                # is dataset within today?
                #   $today_ymd         2019-08-31
                #   $data->{starttime} 2019-08-31T03:58:19.000+02:00
                #   $tomorrow_ymd      2019-08-32 -> OK for stringcompare
                if (  $currentData->{starttime} gt $today_ymd and
                  $currentData->{starttime} lt $tomorrow_ymd )
                {
                  # find first timestamp of today?
                  if ( not defined($dataTodayAnalyzeStartTimestamp) or
                    $currentData->{starttime} lt $dataTodayAnalyzeStartTimestamp )
                  {
                    $dataTodayAnalyzeStartTimestamp = $currentData->{starttime};
                  }

                  # find last timestamp of today?
                  if ( not defined($dataTodayAnalyzeStopTimestamp) or
                    $currentData->{stoptime} gt $dataTodayAnalyzeStopTimestamp )
                  {
                    $dataTodayAnalyzeStopTimestamp = $currentData->{stoptime};
                  }

                  $dataTodayAnalyzeCount     += 1;
                  $dataTodayWaterConsumption += $currentData->{waterconsumption};
                  $dataTodayHotWaterShare    += $currentData->{hotwater_share};
                  $dataTodayWaterCost        += $currentData->{water_cost};
                  $dataTodayEnergyCost       += $currentData->{energy_cost};
                  $dataTodayMaxflowrate = ( $dataTodayMaxflowrate, $currentData->{maxflowrate} )[ $dataTodayMaxflowrate < $currentData->{maxflowrate} ];    # get maximum
                }
              }
            }

            # analysis
            readingsBulkUpdateIfChanged( $hash, "AnalyzeStartTimestamp", $dataAnalyzeStartTimestamp )
              if ( defined($dataAnalyzeStartTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "AnalyzeStopTimestamp", $dataAnalyzeStopTimestamp )
              if ( defined($dataAnalyzeStopTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "AnalyzeCount", $dataAnalyzeCount );

            # last dataset
            readingsBulkUpdateIfChanged( $hash, "LastRequestFromTimestampGMT", $hash->{helper}{lastrequestfromtimestamp} )
              if ( defined( $hash->{helper}{lastrequestfromtimestamp} ) );
            readingsBulkUpdateIfChanged( $hash, "OffsetLocalTimeGMTime", $hash->{helper}{offsetLocalTimeGMTime} )
              if ( defined( $hash->{helper}{offsetLocalTimeGMTime} ) );
            readingsBulkUpdateIfChanged( $hash, "LastStartTimestamp", $dataLastStartTimestamp )
              if ( defined($dataLastStartTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "LastStopTimestamp", $dataLastStopTimestamp )
              if ( defined($dataLastStopTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "LastWaterConsumption", $dataLastWaterconsumption )
              if ( defined($dataLastWaterconsumption) );
            readingsBulkUpdateIfChanged( $hash, "LastMaxFlowRate", $dataLastMaxflowrate )
              if ( defined($dataLastMaxflowrate) );
            readingsBulkUpdateIfChanged( $hash, "LastHotWaterShare", $dataLastHotwaterShare )
              if ( defined($dataLastHotwaterShare) );
            readingsBulkUpdateIfChanged( $hash, "LastWaterCost", $dataLastWaterCost )
              if ( defined($dataLastWaterCost) );
            readingsBulkUpdateIfChanged( $hash, "LastEnergyCost", $dataLastEnergyCost )
              if ( defined($dataLastEnergyCost) );

            # today's and total values
            readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeStartTimestamp", $dataTodayAnalyzeStartTimestamp )
              if ( defined($dataTodayAnalyzeStartTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeStopTimestamp", $dataTodayAnalyzeStopTimestamp )
              if ( defined($dataTodayAnalyzeStopTimestamp) );
            readingsBulkUpdateIfChanged( $hash, "TodayMaxFlowRate", $dataTodayMaxflowrate );

            # AnalyzeCount
            my $deltaTodayAnalyzeCount = $dataTodayAnalyzeCount - ReadingsVal($hash, "TodayAnalyzeCount", 0);
            if($deltaTodayAnalyzeCount > 0) # if there is a change of the value?
            {
              readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeCount", $dataTodayAnalyzeCount );

              my $totalAnalyzeCount = ReadingsVal($hash, "TotalAnalyzeCount", 0) + $deltaTodayAnalyzeCount;
              readingsBulkUpdateIfChanged( $hash, "TotalAnalyzeCount", $totalAnalyzeCount );
            }

            # WaterConsumption
            readingsBulkUpdateIfChanged( $hash, "TodayWaterConsumptionRaw", $dataTodayWaterConsumption );
            my $deltaTodayWaterConsumption = $dataTodayWaterConsumption - ReadingsVal($hash, "TodayWaterConsumption", 0);
            if($deltaTodayWaterConsumption > 0) # if there is a change of the value?
            {
              readingsBulkUpdateIfChanged( $hash, "TodayWaterConsumption", $dataTodayWaterConsumption );

              my $totalWaterConsumptionRaw = ReadingsVal($hash, "TotalWaterConsumptionRaw", 0) + $deltaTodayWaterConsumption;
              readingsBulkUpdateIfChanged( $hash, "TotalWaterConsumptionRaw", $totalWaterConsumptionRaw );
            }

            # HotWaterShare
            readingsBulkUpdateIfChanged( $hash, "TodayHotWaterShareRaw", $dataTodayHotWaterShare );
            my $deltaTodayHotWaterShare = $dataTodayHotWaterShare - ReadingsVal($hash, "TodayHotWaterShare", 0);
            if($deltaTodayHotWaterShare > 0) # if there is a change of the value?
            {
              readingsBulkUpdateIfChanged( $hash, "TodayHotWaterShare", $dataTodayHotWaterShare );

              my $totalHotWaterShareRaw = ReadingsVal($hash, "TotalHotWaterShareRaw", 0) + $deltaTodayHotWaterShare;
              readingsBulkUpdateIfChanged( $hash, "TotalHotWaterShareRaw", $totalHotWaterShareRaw );
            }

            # WaterCost
            readingsBulkUpdateIfChanged( $hash, "TodayWaterCostRaw", $dataTodayWaterCost );
            my $deltaTodayWaterCost = $dataTodayWaterCost - ReadingsVal($hash, "TodayWaterCost", 0);
            if($deltaTodayWaterCost > 0) # if there is a change of the value?
            {
              readingsBulkUpdateIfChanged( $hash, "TodayWaterCost", $dataTodayWaterCost );

              my $totalWaterCostRaw = ReadingsVal($hash, "TotalWaterCostRaw", 0) + $deltaTodayWaterCost;
              readingsBulkUpdateIfChanged( $hash, "TotalWaterCostRaw", $totalWaterCostRaw );
            }

            # EnergyCost
            readingsBulkUpdateIfChanged( $hash, "TodayEnergyCostRaw", $dataTodayEnergyCost);
            my $deltaTodayEnergyCost = $dataTodayEnergyCost - ReadingsVal($hash, "TodayEnergyCost", 0);
            if($deltaTodayEnergyCost > 0) # if there is a change of the value?
            {
              readingsBulkUpdateIfChanged( $hash, "TodayEnergyCost", $dataTodayEnergyCost);

              my $totalEnergyCostRaw = ReadingsVal($hash, "TotalEnergyCostRaw", 0) + $deltaTodayEnergyCost;
              readingsBulkUpdateIfChanged( $hash, "TotalEnergyCostRaw", $totalEnergyCostRaw );
            }
          }
        }

        readingsEndUpdate( $hash, 1 );

        $hash->{helper}{TELEGRAM_DATACOUNTER}++;

        GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($hash);
      }
    }

    if($errorMsg eq "")
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    # get all Data from within today
    # calc gmt from localtime because the grohe cloud works with gmt
    my $requestFromTimestamp     = GroheOndusSmartDevice_GetGMTMidnightDate();

    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId . '/data?from=' . $requestFromTimestamp;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;

    $param->{resultCallback} = $resultCallback;
    
    $hash->{helper}{TELEGRAM_DATAIOWRITE} = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackFail";
      $callbackFail->();
    }
  }
}

##################################
sub GroheOndusSmartDevice_SenseGuard_UpdateOffsetValues($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};
  
  readingsBeginUpdate($hash);

  my $totalWaterConsumptionRaw = ReadingsVal($name, "TotalWaterConsumptionRaw", 0);
  my $totalWaterConsumption = $totalWaterConsumptionRaw + AttrVal($name, "offsetWaterConsumption", 0);
  readingsBulkUpdateIfChanged( $hash, "TotalWaterConsumption", $totalWaterConsumption );

  my $totalHotWaterShareRaw = ReadingsVal($name, "TotalHotWaterShareRaw", 0);
  my $totalHotWaterShare = $totalHotWaterShareRaw + AttrVal($name, "offsetHotWaterShare", 0);
  readingsBulkUpdateIfChanged( $hash, "TotalHotWaterShare", $totalHotWaterShare );
  
  my $totalWaterCostRaw = ReadingsVal($name, "TotalWaterCostRaw", 0);
  my $totalWaterCost = $totalWaterCostRaw + AttrVal($name, "offsetWaterCost", 0);
  readingsBulkUpdateIfChanged( $hash, "TotalWaterCost", $totalWaterCost );
  
  my $totalEnergyCostRaw = ReadingsVal($name, "TotalEnergyCostRaw", 0);
  my $totalEnergyCost = $totalEnergyCostRaw + AttrVal($name, "offsetEnergyCost", 0);
  readingsBulkUpdateIfChanged( $hash, "TotalEnergyCost", $totalEnergyCost );
  
  readingsEndUpdate( $hash, 1 );
}

#################################
sub GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_COMMANDIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - resultCallback";

    if ( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETAPPLIANCECOMMAND_JSON_ERROR";
      }
      else
      {
      # ApplianceCommand:
      # {
      #   "commandb64":"AgI=",
      #   "command":
      #   {
      #     "buzzer_on":false,
      #     "measure_now":false,
      #     "temp_user_unlock_on":false,
      #     "valve_open":true,
      #     "buzzer_sound_profile":2
      #   },
      #   "timestamp":"2019-08-07T04:17:02.985Z",
      #   "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      #   "type":103
      # }
        if (defined( $decode_json->{command} ) and 
          ref( $decode_json->{command} ) eq "HASH" )
        {
          readingsBeginUpdate($hash);

          my $measure_now          = $decode_json->{command}->{measure_now};
          my $temp_user_unlock_on  = $decode_json->{command}->{temp_user_unlock_on};
          my $valve_open           = $decode_json->{command}->{valve_open};
          my $buzzer_on            = $decode_json->{command}->{buzzer_on};
          my $buzzer_sound_profile = $decode_json->{command}->{buzzer_sound_profile};

          # update readings
          readingsBulkUpdateIfChanged( $hash, "CmdMeasureNow",         "$measure_now" );
          readingsBulkUpdateIfChanged( $hash, "CmdTempUserUnlockOn",   "$temp_user_unlock_on" );
          readingsBulkUpdateIfChanged( $hash, "CmdValveOpen",          "$valve_open" );
          readingsBulkUpdateIfChanged( $hash, "CmdValveState",          $valve_open == 1 ? "Open" : "Closed" );
          readingsBulkUpdateIfChanged( $hash, "CmdBuzzerOn",           "$buzzer_on" );
          readingsBulkUpdateIfChanged( $hash, "CmdBuzzerSoundProfile", "$buzzer_sound_profile" );

          readingsEndUpdate( $hash, 1 );
          $hash->{helper}{TELEGRAM_COMMANDCOUNTER}++;
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId . '/command';
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    
    $hash->{helper}{TELEGRAM_COMMANDIOWRITE}  = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - callbackFail";
      $callbackFail->();
    }
  }
}

#####################################
sub GroheOndusSmartDevice_SenseGuard_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_Set($name) - cmd= $cmd";

  ### Command 'update'
  if ( lc $cmd eq lc 'update' )
  {
    GroheOndusSmartDevice_SenseGuard_Update($hash);
  }
  ### Command 'on'
  elsif ( lc $cmd eq lc 'on' )
  {
    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "valve_open", "on")
  }
  ### Command 'off'
  elsif ( lc $cmd eq lc 'off' )
  {
    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "valve_open", "off")
  }
  ### Command 'buzzer'
  elsif ( lc $cmd eq lc 'buzzer' )
  {
    # parameter is "on" or "off" so convert to "true" : "false"
    my $onoff = join( " ", @args ) eq "on" ? "true" : "false";

    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "buzzer_on", $onoff)
  }
  ### Command 'valve'
  elsif ( lc $cmd eq lc 'valve' )
  {
    # parameter is "on" or "off" so convert to "true" : "false"
    my $onoff = join( " ", @args ) eq "on" ? "true" : "false";

    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "valve_open", $onoff)
  }
  ### Command 'clearreadings'
  elsif ( lc $cmd eq lc 'clearreadings' )
  {
    fhem("deletereading $name .*", 1);
  }
  ### Command 'debugRefreshValues'
  elsif ( lc $cmd eq lc 'debugRefreshValues' )
  {
    GroheOndusSmartDevice_SenseGuard_GetData($hash);
  }
  ### Command 'debugRefreshState'
  elsif ( lc $cmd eq lc 'debugRefreshState' )
  {
    GroheOndusSmartDevice_SenseGuard_GetState($hash);
  }
  ### Command 'debugRefreshConfig'
  elsif ( lc $cmd eq lc 'debugRefreshConfig' )
  {
    GroheOndusSmartDevice_SenseGuard_GetConfig($hash);
  }
  ### Command 'debugGetApplianceCommand'
  elsif ( lc $cmd eq lc 'debugGetApplianceCommand' )
  {
    GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($hash);
  }
  ### unknown Command
  else
  {
    my $list = '';
    $list .= 'update:noArg ';
#    $list .= 'on:noArg ';
#    $list .= 'off:noArg ';
    $list .= 'buzzer:on,off ';
    $list .= 'valve:on,off ';
    $list .= 'clearreadings:noArg ';
    
    $list .= 'debugRefreshConfig:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    $list .= 'debugRefreshValues:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    $list .= 'debugRefreshState:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    $list .= 'debugGetApplianceCommand:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    return "Unknown argument $cmd, choose one of $list";
  }
}

#################################
# $command:
#  "buzzer_on"
#  "buzzer_sound_profile"
#  "measure_now"
#  "pressure_measurement_running"
#  "reason_for_change"
#  "temp_user_unlock_on"
#  "valve_open"
sub GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($$$;$$)
{
  my ( $hash, $command, $setValue, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{SetApplianceCommandIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - resultCallback";

    if( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "SETAPPLIANCECOMMAND_JSON_ERROR";
      }
      else
      {
        # ApplianceCommand:
        # {
        #   "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        #   "type":103
        #   "command":
        #   {
        #     "buzzer_on":false,
        #     "buzzer_sound_profile":2,
        #     "measure_now":false,
        #     "pressure_measurement_running":false,
        #     "reason_for_change":1,
        #     "temp_user_unlock_on":false,
        #     "valve_open":true,
        #   },
        # }
        if (defined( $decode_json->{command} ) and 
          ref( $decode_json->{command} ) eq "HASH" )
        {
          readingsBeginUpdate($hash);

          my $buzzer_on                    = $decode_json->{command}->{buzzer_on};
          my $buzzer_sound_profile         = $decode_json->{command}->{buzzer_sound_profile};
          my $measure_now                  = $decode_json->{command}->{measure_now};
          my $pressure_measurement_running = $decode_json->{command}->{pressure_measurement_running};
          my $reason_for_change            = $decode_json->{command}->{reason_for_change};
          my $temp_user_unlock_on          = $decode_json->{command}->{temp_user_unlock_on};
          my $valve_open                   = $decode_json->{command}->{valve_open};

          # update readings
          readingsBulkUpdateIfChanged( $hash, "CmdBuzzerOn",                   "$buzzer_on" );
          readingsBulkUpdateIfChanged( $hash, "CmdBuzzerSoundProfile",         "$buzzer_sound_profile" );
          readingsBulkUpdateIfChanged( $hash, "CmdMeasureNow",                 "$measure_now" );
          readingsBulkUpdateIfChanged( $hash, "CmdPressureMeasurementRunning", "$pressure_measurement_running" );
          readingsBulkUpdateIfChanged( $hash, "CmdReasonForChange",            "$reason_for_change" );
          readingsBulkUpdateIfChanged( $hash, "CmdTempUserUnlockOn",           "$temp_user_unlock_on" );
          readingsBulkUpdateIfChanged( $hash, "CmdValveOpen",                  "$valve_open" );
          readingsBulkUpdateIfChanged( $hash, "CmdValveState",                  $valve_open == 1 ? "Open" : "Closed" );

          readingsEndUpdate( $hash, 1 );
          $hash->{helper}{TELEGRAM_COMMANDVALVECOUNTER}++;
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    GroheOndusSmartDevice_Debug_Update($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $setValueString = "false";
    if( defined($setValue))
    {
      if( lc $setValue eq "true" or
        lc $setValue eq "on" or
        $setValue != 0)
      {
      	$setValueString = "true";
      }
    }
    
    # values have to be lowercase! 
    my $commandData = 
    {
      'appliance_id' => $deviceId,
      'type'         => $modelId,
      'command'      => 
      {
        # 'measure_now' = 
        # 'buzzer_on' =>
        # 'buzzer_sound_profile' => 
        $command => lc $setValueString
        # 'temp_user_unlock_on' =>
      }
    };

    my $param = {};
    $param->{method} = 'POST';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId . '/command';
    $param->{header} = "Content-Type: application/json";
    $param->{data} = encode_json($commandData);
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    
    $hash->{SetApplianceCommandIOWRITE}  = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - callbackFail";
      $callbackFail->();
    }
  }
}

##################################
sub GroheOndusSmartDevice_Sense_Update($)
{
  my ( $hash ) = @_;
  my $name     = $hash->{NAME};

  Log3 $name, 4, "GroheOndusSmartDevice_Sense_Update($name)";

  # paralleles Abrufen!
  #GroheOndusSmartDevice_Sense_GetData($hash);
  #GroheOndusSmartDevice_Sense_GetState($hash);
  #GroheOndusSmartDevice_Sense_GetConfig($hash);
  
  # serielles Abrufen
  my $getData = sub { GroheOndusSmartDevice_Sense_GetData($hash); };
  my $getState = sub { GroheOndusSmartDevice_Sense_GetState($hash, $getData); };
  my $getConfig = sub { GroheOndusSmartDevice_Sense_GetConfig($hash, $getState); };
  
  $getConfig->();
}

##################################
sub GroheOndusSmartDevice_Sense_GetState($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name     = $hash->{NAME};
  my $modelId = 100;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_STATUSIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - resultCallback";

    if( $errorMsg eq "")
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_Sense_GetState($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETSTATE_JSON_ERROR";
      }
      else
      {
        # Status:
        # {
        #   [
        #     {
        #       "type":"update_available",
        #       "value":0
        #     },
        #     {
        #       "type":"battery"
        #       "value":100,
        #     },
        #     {
        #       "type":"connection",
        #       "value":1
        #     },
        #     {
        #       "type":"wifi_quality",
        #       "value":0
        #     }
        #   ]
        # }
        if ( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          readingsBeginUpdate($hash);
    
          foreach my $currentData ( @{ $decode_json } )
          {
            if ( $currentData->{type} eq "update_available"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateUpdateAvailable", $currentData->{value} );
            } 
            elsif ( $currentData->{type} eq "battery"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateBattery", $currentData->{value} );
            } 
            elsif ( $currentData->{type} eq "connection"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateConnection", $currentData->{value} );
            } 
            elsif ( $currentData->{type} eq "wifi_quality"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateWifiQuality", $currentData->{value} );
            } 
            else
            {
              # write json string to reading "unknown"
              readingsBulkUpdateIfChanged( $hash, "State_unknown-data", encode_json($currentData) );
            }
          }

          readingsEndUpdate( $hash, 1 );
          $hash->{helper}{TELEGRAM_STATUSCOUNTER}++;
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    GroheOndusSmartDevice_Debug_Update($hash);

    if($errorMsg eq "")
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId . '/status';
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;

    $param->{resultCallback} = $resultCallback;

    $hash->{helper}{TELEGRAM_STATUSIOWRITE} = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - callbackFail";
      $callbackFail->();
    }
  }
}

##################################
sub GroheOndusSmartDevice_Sense_GetConfig($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_CONFIGIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - resultCallback";

    if( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_Sense_GetConfig($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETCONFIG_JSON_ERROR";
      }
      else
      {
      # config:
      #{
      #   "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
      #   "installation_date":"2001-01-30T00:00:00.000+00:00",
      #   "name":"KG Vorratsraum Sense",
      #   "serial_number":"123456789012345678901234567890123456789012345678",
      #   "type":101,
      #   "version":"1547",
      #   "tdt":"2019-06-30T05:15:38.000+02:00",
      #   "timezone":60,
      #   "role":"owner",
      #   "registration_complete":true,
      #   "config":
      #   {
      #       "thresholds":
      #       [
      #           {
      #               "quantity":"temperature",
      #               "type":"min",
      #               "value":10,
      #               "enabled":true
      #           },
      #           {
      #               "quantity":"temperature",
      #               "type":"max",
      #               "value":35,
      #               "enabled":true
      #           },
      #           {
      #               "quantity":"humidity",
      #               "type":"min",
      #               "value":30,
      #               "enabled":true
      #           },
      #           {
      #               "quantity":"humidity",
      #               "type":"max",
      #               "value":65,
      #               "enabled":true
      #           }
      #       ]
      #   }
      #}
      #]
      
        if ( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          readingsBeginUpdate($hash);

        #     "appliance_id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
        #     "installation_date":"2019-01-30T06:32:37.000+00:00",
        #     "name":"KG Vorratsraum SenseGUARD",
        #     "serial_number":"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        #     "type":103,
        #     "version":"01.44.Z22.0400.0101",
        #     "tdt":"2021-10-09T06:35:25.000+02:00",
        #     "timezone":60,
        #     "role":"owner",
        #     "registration_complete":true,

          my $currentEntry = $decode_json->[0];

          if ( defined( $currentEntry )
            and ref( $currentEntry ) eq "HASH" )
          {
            readingsBulkUpdateIfChanged( $hash, "ApplianceID", "$currentEntry->{appliance_id}" )
              if( defined( $currentEntry->{appliance_id} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceInstallationDate", "$currentEntry->{installation_date}" )
              if( defined( $currentEntry->{installation_date} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceName", "$currentEntry->{name}" )
              if( defined( $currentEntry->{name} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceSerialNumber", "$currentEntry->{serial_number}" )
              if( defined( $currentEntry->{serial_number} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceType", "$currentEntry->{type}" )
              if( defined( $currentEntry->{type} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceVersion", "$currentEntry->{version}" )
              if( defined( $currentEntry->{version} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceTDT", "$currentEntry->{tdt}" )
              if( defined( $currentEntry->{tdt} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceTimezone", "$currentEntry->{timezone}" )
              if( defined( $currentEntry->{timezone} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceRole", "$currentEntry->{role}" )
              if( defined( $currentEntry->{role} ) );
            readingsBulkUpdateIfChanged( $hash, "ApplianceRegistrationComplete", "$currentEntry->{registration_complete}" )
              if( defined( $currentEntry->{registration_complete} ) );

            my $currentConfig = $currentEntry->{config};

            if ( defined( $currentConfig )
              and ref( $currentConfig ) eq "HASH" )
            {
      #   "config":
      #   {
      #       "thresholds":
      #       [
      #           {
      #               "quantity":"temperature",
      #               "type":"min",
      #               "value":10,
      #               "enabled":true
      #           },
      #           {
      #               "quantity":"temperature",
      #               "type":"max",
      #               "value":35,
      #               "enabled":true
      #           },
      #           {
      #               "quantity":"humidity",
      #               "type":"min",
      #               "value":30,
      #               "enabled":true
      #           },
      #           {
      #               "quantity":"humidity",
      #               "type":"max",
      #               "value":65,
      #               "enabled":true
      #           }
      #       ]
      #   }

              my $currentThresholds = $currentConfig->{thresholds};

              if ( defined( $currentThresholds ) and
                ref( $currentThresholds ) eq "ARRAY" )
              {
                foreach my $currentThreshold ( @{ $currentThresholds} )
                {
                  if ( "$currentThreshold->{quantity}" eq "temperature" )
                  {
                    if ( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif ( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  } 
                  elsif ( "$currentThreshold->{quantity}" eq "humidity" )
                  {
                    if ( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigHumidityThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif ( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigHumidityThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  }
                }
              }
            }
          }
          readingsEndUpdate( $hash, 1 );

          $hash->{helper}{TELEGRAM_CONFIGCOUNTER}++;
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    GroheOndusSmartDevice_Debug_Update($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    
    $hash->{helper}{TELEGRAM_CONFIGIOWRITE} = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - callbackFail";
      $callbackFail->();
    }
  }
}

##################################
sub GroheOndusSmartDevice_Sense_GetData($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name     = $hash->{NAME};
  my $modelId = 100;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    $hash->{helper}{TELEGRAM_DATAIOCALLBACK}  = strftime($TimeStampFormat, localtime(gettimeofday()));
    Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - resultCallback";

    if( $errorMsg eq "" )
    {
      my $decode_json = eval { decode_json($data) };
    
      if ($@)
      {
        Log3 $name, 3, "GroheOndusSmartDevice_Sense_GetData($name) - JSON error while request: $@";

        if ( AttrVal( $name, 'debugJSON', 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, 'JSON_ERROR', $@, 1 );
          readingsBulkUpdate( $hash, 'JSON_ERROR_STRING', '\'' . $data . '\'', 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GETDATA_JSON_ERROR";
      }
      else
      {
      # Data:
      # {
      #   "data":
      #   {
      #     "measurement":
      #     [
      #       {
      #         "timestamp":"2019-01-30T08:04:27.000+01:00",
      #         "humidity":54,
      #         "temperature":19.4
      #       },
      #       {
      #         "timestamp":"2019-01-30T08:04:28.000+01:00",
      #         "humidity":53,
      #         "temperature":19.4
      #       }
      #     ],
      #     "withdrawals":
      #      [
      #      ]
      #    },
      # }
        if ( defined( $decode_json ) and
          defined( $decode_json->{data}->{measurement} ) and
          ref( $decode_json->{data}->{measurement} ) eq "ARRAY" )
        {
          $hash->{helper}{TELEGRAM_DATACOUNTER}++;

          # get entry with latest timestamp
          my $dataTimestamp;
          my $dataHumidity;
          my $dataTemperature;
          my $loopCounter = 0;

          foreach my $currentData ( @{ $decode_json->{data}->{measurement} } )
          {
            # is this the correct dataset?
            if (  defined( $currentData->{timestamp} )
              and defined( $currentData->{humidity} )
              and defined( $currentData->{temperature} ) )
            {
              # is timestamp newer?
              if ( not defined($dataTimestamp)
                or $currentData->{timestamp} gt $dataTimestamp )
              {
                $dataTimestamp   = $currentData->{timestamp};
                $dataHumidity    = $currentData->{humidity};
                $dataTemperature = $currentData->{temperature};
              }
            }
            $loopCounter++;
          }

          $hash->{STATISTICDATALOOPCOUNTER} = $loopCounter;

          readingsBeginUpdate($hash);

          readingsBulkUpdateIfChanged( $hash, "LastDataTimestamp", $dataTimestamp )
            if ( defined($dataTimestamp) );
          readingsBulkUpdateIfChanged( $hash, "LastHumidity", $dataHumidity )
            if ( defined($dataHumidity) );
          readingsBulkUpdateIfChanged( $hash, "LastTemperature", $dataTemperature )
            if ( defined($dataTemperature) );

          readingsEndUpdate( $hash, 1 );

          $hash->{helper}{TELEGRAM_DATACOUNTER}++;
        }
        # {
        #   "code":404,
        #   "message":"Not found"
        # }
        elsif ( defined( $decode_json ) and
          defined( $decode_json->{code} ) and
          defined( $decode_json->{message} ) )
        {
          my $errorCode = $decode_json->{code};
          my $errorMessage = $decode_json->{message};
          my $message = 'TimeStamp: ' . strftime($TimeStampFormat, localtime(gettimeofday())) . ' Code: ' . $errorCode . ' Message: ' . $decode_json->{message}; 

          # Not found -> no data in requested timespan
          if( $errorCode == 404 )
          {
            Log3 $name, 3, "GroheOndusSmartDevice_Sense_GetData($name) - $message";
            readingsSingleUpdate( $hash, 'Message', $message, 1 );
          }
          # Too many requests 
          elsif ($errorCode == 429)
          {
            Log3 $name, 3, "GroheOndusSmartDevice_Sense_GetData($name) - $message";
            readingsSingleUpdate( $hash, 'Message', $message, 1 );
          }
          else
          {
            Log3 $name, 3, "GroheOndusSmartDevice_Sense_GetData($name) - $message";
            readingsSingleUpdate( $hash, 'Message', $message, 1 );
          }
        }
        else
        {
          $errorMsg = "UNKNOWN DATA";
        }
      }
    }

    GroheOndusSmartDevice_Debug_Update($hash);

    if($errorMsg eq "")
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackSuccess";
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, 'state', $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackFail";
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{location_id};
  my $device_roomId     = $hash->{room_id};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    # get all Data from within today
    # calc gmt from localtime because the grohe cloud works with gmt
    my $requestFromTimestamp = GroheOndusSmartDevice_GetGMTMidnightDate();

    my $param = {};
    $param->{method} = 'GET';
    $param->{url} = $hash->{IODev}{URL} . '/iot/locations/' . $device_locationId . '/rooms/' . $device_roomId . '/appliances/' . $deviceId . '/data?from=' . $requestFromTimestamp;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
    
    $param->{resultCallback} = $resultCallback;

    $hash->{helper}{TELEGRAM_DATAIOWRITE} = strftime($TimeStampFormat, localtime(gettimeofday()));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3 $name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackFail";
      $callbackFail->();
    }
  }
}

#####################################
sub GroheOndusSmartDevice_Sense_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  ### Command 'update'
  if ( lc $cmd eq lc 'update' )
  {
    GroheOndusSmartDevice_Sense_Update($hash);
  }
  ### Command 'clearreadings'
  elsif ( lc $cmd eq lc 'clearreadings' )
  {
    fhem("deletereading $name .*", 1);
  }
  ### Command 'debugRefreshValues'
  elsif ( lc $cmd eq lc 'debugRefreshValues' )
  {
    GroheOndusSmartDevice_Sense_GetData($hash);
  }
  ### Command 'debugRefreshState'
  elsif ( lc $cmd eq lc 'debugRefreshState' )
  {
    GroheOndusSmartDevice_Sense_GetState($hash);
  }
  ### Command 'debugRefreshConfig'
  elsif ( lc $cmd eq lc 'debugRefreshConfig' )
  {
    GroheOndusSmartDevice_Sense_GetConfig($hash);
  }
  ### unknown Command
  else
  {
    my $list = '';
    
    $list .= 'update:noArg ';
    $list .= 'clearreadings:noArg ';
    
    $list .= 'debugRefreshConfig:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    $list .= 'debugRefreshValues:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    $list .= 'debugRefreshState:noArg '
      if($hash->{helper}{DEBUG} ne '0');

    return "Unknown argument $cmd, choose one of $list";
  }
}

##################################
# This methode calculates the offset in hours from GMT and localtime
# returns ($offsetLocalTimeGMT_hours)
sub GroheOndusSmartDevice_GetGMTOffset()
{
  # it seems that the timestamp for this command has to be in GMT
  # we want to request all data from within the current day beginning from 00:00:00
  # so we need to transform the current date 00:00:00 to GMT
  # localtime           -> request GMT
  # 2019.31.08T23:xx:xx -> 2019.30.08T22:00:00
  # 2019.01.09T00:xx:xx -> 2019.30.08T22:00:00
  # 2019.01.09T01:xx:xx -> 2019.30.08T22:00:00
  # 2019.01.09T02:xx:xx -> 2019.31.08T22:00:00
  # 2019.01.09T03:xx:xx -> 2019.31.08T22:00:00
  my $currentTimestamp = gettimeofday();

  # calculate the offset between localtime and GMT in hours
  #my $offsetLocalTimeGMTime = localtime($currentTimestamp) - gmtime($currentTimestamp);
  my $offsetLocalTimeGMT_hours = ( localtime $currentTimestamp + 3600 * ( 12 - (gmtime)[2] ) )[2] - 12;

  return ($offsetLocalTimeGMT_hours);
}

##################################
# This methode returns today's date convertet to GMT
# returns $gmtMidnightDate
sub GroheOndusSmartDevice_GetGMTMidnightDate()
{
  # it seems that the timestamp for this command has to be in GMT
  # we want to request all data from within the current day beginning from 00:00:00
  # so we need to transform the current date 00:00:00 to GMT
  # localtime           -> request GMT
  # 2019.31.08T23:xx:xx -> 2019.30.08T22:00:00
  # 2019.01.09T00:xx:xx -> 2019.30.08T22:00:00
  # 2019.01.09T01:xx:xx -> 2019.30.08T22:00:00
  # 2019.01.09T02:xx:xx -> 2019.31.08T22:00:00
  # 2019.01.09T03:xx:xx -> 2019.31.08T22:00:00
  my $currentTimestamp = gettimeofday();

  # calculate the offset between localtime and GMT in hours
  my $offsetLocalTimeGMT_hours = GroheOndusSmartDevice_GetGMTOffset();

  # current date in Greenwich
  my ( $d, $m, $y ) = ( gmtime($currentTimestamp) )[ 3, 4, 5 ];

  # Greenwich's date minus offset
  my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) = gmtime( timegm( 0, 0, 0, $d, $m, $y ) - $offsetLocalTimeGMT_hours * 3600 );

  # today -> get all data from within this day
  #my $requestFromTimestamp = sprintf("%04d-%02d-%02d", $year+1900, $month+1, $mday);
  my $gmtMidnightDate = sprintf( "%04d-%02d-%02dT%02d:00:00", $year + 1900, $month + 1, $mday, $hour );

  return $gmtMidnightDate;
}

1;

=pod

=item device
=item summary    Modul to control GroheOndusSmart Devices
=item summary_DE Modul zur Steuerung von GroheOndusSmartger&aumlten

=begin html

<a name="GroheOndusSmartDevice"></a>
<h3>GroheOndusSmartDevice</h3>
<ul>
    In combination with GroheOndusSmartBridge this FHEM Module controls the GroheOndusSmart Device using the GroheOndusCloud
    <br><br>
    Once the Bridge device is created, the connected devices are automatically recognized and created in FHEM. <br>
    From now on the devices can be controlled and changes in the GroheOndusAPP are synchronized with the state and readings of the devices.
    <a name="GroheOndusSmartDevicereadings"></a>
    <br><br><br>
    <b>Readings</b>
    <ul>
        <li>ApplianceID - ID of the device</li>
        <li>ApplianceInstallationDate - installation date of the device</li>
        <li>ApplianceName - name of the device set with GroheOndusAPP</li>
    </ul>
    <br><br>
    <a name="GroheOndusSmartDeviceattributes"></a>
    <b>Attributes</b>
    <ul>
        <li>model - model of the device: sense/sense_guard</li>
        <li>interval - Interval in seconds</li>
    </ul>
    <br><br>
    <a name="GroheOndusSmartDeviceset"></a>
    <b>set</b>
    <ul>
        <li>refreshState</li>
        <li>refreshValues</li>
    </ul>
</ul>

=end html
=begin html_DE

<a name="GroheOndusSmartDevice"></a>
<h3>GroheOndusSmartDevice</h3>
<ul>
    Zusammen mit dem Device GroheOndusSmartDevice stellt dieses FHEM Modul die Kommunikation zwischen der GroheOndusCloud und Fhem her.
    <br><br>
    Wenn das GroheOndusSmartBridge Device erzeugt wurde, werden verbundene Ger&auml;te automatisch erkannt und in Fhem angelegt.<br> 
    Von nun an k&ouml;nnen die eingebundenen Ger&auml;te gesteuert werden. &Auml;nderungen in der APP werden mit den Readings und dem Status syncronisiert.
    <a name="GroheOndusSmartDevicereadings"></a>
    </ul>
    <br>
    <ul>
    <b>Readings</b>
    <ul>
        <li>ApplianceID - ID des Ger&auml;tes</li>
        <li>ApplianceInstallationDate - Installationdatum des Ger&auml;tes</li>
        <li>ApplianceName - Name des Ger&auml;tes, der in der GroheOndusAPP gesetzt wurde</li>
    </ul>
    <br><br>
    <a name="GroheOndusSmartDeviceattributes"></a>
    <b>Attribute</b>
    <ul>
        <li>model - Modell des Ger&auml;tes: sense/sense_guard</li>
        <li>interval - Abfrageintervall in Sekunden</li>
    </ul>
    <a name="GroheOndusSmartDeviceset"></a>
    <b>set</b>
    <ul>
        <li>refreshState</li>
        <li>refreshValues</li>
    </ul>
</ul>

=end html_DE

=for :application/json;q=META.json 74_GroheOndusSmartDevice.pm
{
  "abstract": "Modul to control GroheOndusSmart Devices",
  "x_lang": {
    "de": {
      "abstract": "Modul zur Steuerung von GroheOndus Smart Ger&aumlten"
    }
  },
  "keywords": [
    "fhem-mod-device",
    "fhem-core",
    "GroheOndus",
    "Smart"
  ],
  "release_status": "stable",
  "license": "GPL_2",
  "author": [
    "J0EK3R <J0EK3R@gmx.net>"
  ],
  "x_fhem_maintainer": [
    ""
  ],
  "x_fhem_maintainer_github": [
    "J0EK3R"
  ],
  "prereqs": {
    "runtime": {
      "requires": {
        "FHEM": 5.00918799,
        "perl": 5.016, 
        "Meta": 0,
        "JSON": 0,
        "Time::Local": 0
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
