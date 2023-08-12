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
# $Id: 74_GroheOndusSmartDevice.pm 201 2020-04-04 06:14:00Z J0EK3R $
#
###############################################################################

package main;

my $VERSION = "4.0.6";

use strict;
use warnings;

my $missingModul = "";

use FHEM::Meta;
use Date::Parse;
use Time::Local;
use Time::HiRes qw(gettimeofday);
eval {use JSON;1 or $missingModul .= "JSON "};

#########################
# Forward declaration
sub GroheOndusSmartDevice_Initialize($);
sub GroheOndusSmartDevice_Define($$);
sub GroheOndusSmartDevice_Undef($$);
sub GroheOndusSmartDevice_Delete($$);
sub GroheOndusSmartDevice_Rename($$);
sub GroheOndusSmartDevice_Attr(@);
sub GroheOndusSmartDevice_Notify($$);
sub GroheOndusSmartDevice_Set($@);
sub GroheOndusSmartDevice_Parse($$);

sub GroheOndusSmartDevice_Upgrade($);
sub GroheOndusSmartDevice_UpdateInternals($);

sub GroheOndusSmartDevice_TimerExecute($);
sub GroheOndusSmartDevice_TimerRemove($);

sub GroheOndusSmartDevice_IOWrite($$);

sub GroheOndusSmartDevice_SenseGuard_Update($);
sub GroheOndusSmartDevice_SenseGuard_GetState($;$$);
sub GroheOndusSmartDevice_SenseGuard_GetConfig($;$$);
sub GroheOndusSmartDevice_SenseGuard_Set($@);

sub GroheOndusSmartDevice_SenseGuard_GetData($$;$$);
sub GroheOndusSmartDevice_SenseGuard_GetData_Last($;$$);
sub GroheOndusSmartDevice_SenseGuard_GetData_Stop($);
sub GroheOndusSmartDevice_SenseGuard_GetData_StartCampain($$;$$);
sub GroheOndusSmartDevice_SenseGuard_GetData_TimerExecute($);
sub GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($);

sub GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($;$$);
sub GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($$$;$$);

sub GroheOndusSmartDevice_Sense_Update($);
sub GroheOndusSmartDevice_Sense_GetState($;$$);
sub GroheOndusSmartDevice_Sense_GetConfig($;$$);
sub GroheOndusSmartDevice_Sense_Set($@);

sub GroheOndusSmartDevice_Sense_GetData($$;$$);
sub GroheOndusSmartDevice_Sense_GetData_Last($;$$);
sub GroheOndusSmartDevice_Sense_GetData_Stop($);
sub GroheOndusSmartDevice_Sense_GetData_StartCampain($$;$$);
sub GroheOndusSmartDevice_Sense_GetData_TimerExecute($);
sub GroheOndusSmartDevice_Sense_GetData_TimerRemove($);

sub GroheOndusSmartDevice_Blue_Update($);
sub GroheOndusSmartDevice_Blue_GetState($;$$);
sub GroheOndusSmartDevice_Blue_GetConfig($;$$);
sub GroheOndusSmartDevice_Blue_Set($@);

sub GroheOndusSmartDevice_Blue_GetData($$;$$);
sub GroheOndusSmartDevice_Blue_GetData_Last($;$$);
sub GroheOndusSmartDevice_Blue_GetData_Stop($);
sub GroheOndusSmartDevice_Blue_GetData_StartCampain($$;$$);
sub GroheOndusSmartDevice_Blue_GetData_TimerExecute($);
sub GroheOndusSmartDevice_Blue_GetData_TimerRemove($);

sub GroheOndusSmartDevice_Blue_GetApplianceCommand($;$$);

sub GroheOndusSmartDevice_FileLog_MeasureValueWrite($$$@);
sub GroheOndusSmartDevice_FileLog_Delete($$);
sub GroheOndusSmartDevice_FileLog_Create_FileLogDevice($;$);

sub GroheOndusSmartDevice_Store($$$$);
sub GroheOndusSmartDevice_Restore($$$$);
sub GroheOndusSmartDevice_StoreRename($$$$);

sub GroheOndusSmartDevice_GetLTZStringFromLUTC($);
sub GroheOndusSmartDevice_GetLTZFromLUTC($);
sub GroheOndusSmartDevice_GetUTCFromLUTC($);
sub GroheOndusSmartDevice_GetUTCFromLTZ($);

sub GroheOndusSmartDevice_GetUTCMidnightDate($);
sub GroheOndusSmartDevice_GetLTZMidnightDate();

sub GroheOndusSmartDevice_Getnum($);

sub GroheOndusSmartDevice_PostFn($$);

#########################
# Constants

my $GetLoopDataInterval                   = 1;     # interval of the data-get-timer

my $SenseGuard_DefaultInterval            = 60 * 1; # default value for the polling interval in seconds
my $SenseGuard_DefaultStateFormat         = "State: state<br/>Valve: CmdValveState<br/>Consumption: TodayWaterConsumption l<br/>Temperature: LastTemperature Grad C<br/>Pressure: LastPressure bar";
my $SenseGuard_DefaultWebCmdFormat        = "valve on:valve off"; # "update:valve on:valve off"
my $SenseGuard_DefaultGetTimespan         = 60 * 60 * 24 * 1; # 1 days

my $Sense_DefaultInterval                 = 60 * 10;     # default value for the polling interval in seconds
my $Sense_DefaultStateFormat              = "State: state<br/>Temperature: LastTemperature Grad C<br/>Humidity: LastHumidity %";
my $Sense_DefaultWebCmdFormat             = ""; # "update"
my $Sense_DefaultGetTimespan              = 60 * 60 * 24 * 30; # 30 days

my $Blue_DefaultInterval                 = 60 * 10;     # default value for the polling interval in seconds
my $Blue_DefaultStateFormat              = "State: state";
my $Blue_DefaultWebCmdFormat             = ""; # "update"
my $Blue_DefaultGetTimespan              = 60 * 60 * 24 * 30; # 30 days

my $DefaultLogfilePattern                 = "%L/<name>-Data-%Y-%m.log";
my $DefaultLogfileFormat                  = "Measurement";

my $TimeStampFormat                       = "%Y-%m-%dT%I:%M:%S";

my $ForcedTimeStampLength                 = 10;
my $CurrentMeasurementFormatVersion       = "00";

my %replacechartable = ("ä" => "ae", "Ä" => "Ae", "ü" => "ue", "Ü" => "Ue", "ö" => "oe", "Ö" => "Oe", "ß" => "ss" );
my $replacechartablekeys = join ("|", keys(%replacechartable));

# AttributeList for all types of GroheOndusSmartDevice 
my $GroheOndusSmartDevice_AttrList = 
    "debug:0,1 " . 
    "debugJSON:0,1 " . 
    "disable:0,1 " . 
    "interval " .
    ""; 

# AttributeList including deprecated attributes
my $GroheOndusSmartDevice_AttrList_Deprecated = 
    "model:sense,sense_guard " . 
    "IODev "; 

# AttributeList for SenseGuard
my $GroheOndusSmartDevice_SenseGuard_AttrList = 
    "offsetTotalEnergyCost " . 
    "offsetTotalWaterCost " . 
    "offsetTotalWaterConsumption " . 
    "offsetTotalHotWaterShare " .
    "logFileEnabled:0,1 " .
    "logFileFormat:MeasureValue,Measurement " . 
    "logFilePattern " .
    "logFileGetDataStartDate " .
    ""; 

# AttributeList for Sense
my $GroheOndusSmartDevice_Sense_AttrList = 
    "logFileEnabled:0,1 " .
    "logFileFormat:MeasureValue,Measurement " . 
    "logFilePattern " .
    "logFileGetDataStartDate " .
    ""; 

# AttributeList for Blue
my $GroheOndusSmartDevice_Blue_AttrList = 
    "logFileEnabled:0,1 " .
    "logFileFormat:MeasureValue,Measurement " . 
    "logFilePattern " .
    "logFileGetDataStartDate " .
    ""; 

#####################################
# GroheOndusSmartDevice_Initialize( $hash )
sub GroheOndusSmartDevice_Initialize($)
{
  my ( $hash ) = @_;

  $hash->{DefFn}    = \&GroheOndusSmartDevice_Define;
  $hash->{UndefFn}  = \&GroheOndusSmartDevice_Undef;
  $hash->{DeleteFn} = \&GroheOndusSmartDevice_Delete;
  $hash->{RenameFn} = \&GroheOndusSmartDevice_Rename;
  $hash->{AttrFn}   = \&GroheOndusSmartDevice_Attr;
  $hash->{NotifyFn} = \&GroheOndusSmartDevice_Notify;
  $hash->{SetFn}    = \&GroheOndusSmartDevice_Set;
  $hash->{ParseFn}  = \&GroheOndusSmartDevice_Parse;

  $hash->{Match} = "^GROHEONDUSSMARTDEVICE_.*";
  
  # list of attributes has changed from V2 -> V3
  # -> the redefinition is done automatically
  # old attribute list is set to be able to get the deprecated attribute values
  # on global event "INITIALIZED" the new attribute list is set 
  $hash->{AttrList} = 
    $GroheOndusSmartDevice_AttrList . 
    $readingFnAttributes;

  foreach my $d ( sort keys %{ $modules{GroheOndusSmartDevice}{defptr} } )
  {
    my $hash = $modules{GroheOndusSmartDevice}{defptr}{$d};
    $hash->{VERSION} = $VERSION;
  }

  return FHEM::Meta::InitMod( __FILE__, $hash );
}

#####################################
# GroheOndusSmartDevice_Define( $hash, $def )
sub GroheOndusSmartDevice_Define($$)
{
  my ($hash, $def) = @_;
  my @a = split("[ \t]+", $def);

  return $@
    unless(FHEM::Meta::SetInternals($hash));

  return "Cannot define GroheOndusSmartDevice. Perl modul $missingModul is missing."
    if($missingModul);

  # set marker to prevent actions while define is running
  $hash->{helper}{DefineRunning} = "Running";

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
    
    CommandAttr(undef, "$name IODev $modules{GroheOndusSmartBridge}{defptr}{BRIDGE}->{NAME}")
      if(AttrVal( $name, "IODev", "none" ) eq "none");

    $bridge = AttrVal($name, "IODev", "none");
    
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

  # set model depending defaults
  ### sense_guard
  if($model eq "sense_guard")
  {
    # the SenseGuard devices update every 15 minutes
    $hash->{".DEFAULTINTERVAL"} = $SenseGuard_DefaultInterval;
    $hash->{".DEFAULTGETTIMESPAN"}  = $SenseGuard_DefaultGetTimespan;
    $hash->{".AttrList"} =
      $GroheOndusSmartDevice_AttrList .
      $GroheOndusSmartDevice_SenseGuard_AttrList . 
      $readingFnAttributes;

    $hash->{helper}{Telegram_GetConfigCounter}  = 0;
    $hash->{helper}{Telegram_GetStateCounter}   = 0;
    $hash->{helper}{Telegram_GetDataCounter}    = 0;
    $hash->{helper}{Telegram_GetCommandCounter} = 0;
    $hash->{helper}{Telegram_SetCommandCounter} = 0;

    $hash->{helper}{OffsetEnergyCost}           = 0;
    $hash->{helper}{OffsetWaterCost}            = 0;
    $hash->{helper}{OffsetWaterConsumption}     = 0; 
    $hash->{helper}{OffsetHotWaterShare}        = 0;

    # set defaults
    $hash->{helper}{GetSuspendReadings}                     = "0";
    $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC}  = "";
    $hash->{helper}{LastProcessedTimestamp_LUTC}            = "";

    $hash->{helper}{TotalAnalyzeStartTimestamp}             = "";
    $hash->{helper}{TotalAnalyzeEndTimestamp}               = "";
    $hash->{helper}{TotalWithdrawalCount}                   = 0;
    $hash->{helper}{TotalWaterConsumption}                  = 0;
    $hash->{helper}{TotalHotWaterShare}                     = 0;
    $hash->{helper}{TotalWaterCost}                         = 0;
    $hash->{helper}{TotalEnergyCost}                        = 0;

    $hash->{helper}{TodayAnalyzeStartTimestamp}             = "";
    $hash->{helper}{TodayAnalyzeEndTimestamp}               = "";
    $hash->{helper}{TodayWithdrawalCount}                   = 0;
    $hash->{helper}{TodayWaterConsumption}                  = 0;
    $hash->{helper}{TodayHotWaterShare}                     = 0;
    $hash->{helper}{TodayWaterCost}                         = 0;
    $hash->{helper}{TodayEnergyCost}                        = 0;
    $hash->{helper}{TodayMaxFlowrate}                       = 0;

    if($init_done)
    {
      # device is created *after* fhem has started -> don't restore old values
      Log3($name, 5, "GroheOndusSmartDevice_Define($name) - device is created after fhem has started -> don't restore old values");
    }
    else
    {
      # device is created *while* fhem is starting -> restore old values
      Log3($name, 5, "GroheOndusSmartDevice_Define($name) - device is created while fhem is starting -> restore old values");

      $hash->{helper}{GetSuspendReadings}                     = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});
      $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC}  = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "LastProcessedWithdrawalTimestamp_LUTC", $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC});
      $hash->{helper}{LastProcessedTimestamp_LUTC}            = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "LastProcessedTimestamp_LUTC", $hash->{helper}{LastProcessedTimestamp_LUTC});

      $hash->{helper}{TotalAnalyzeStartTimestamp}             = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalAnalyzeStartTimestamp", $hash->{helper}{TotalAnalyzeStartTimestamp});
      $hash->{helper}{TotalAnalyzeEndTimestamp}               = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalAnalyzeEndTimestamp", $hash->{helper}{TotalAnalyzeEndTimestamp});
      $hash->{helper}{TotalWithdrawalCount}                   = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalWithdrawalCount", $hash->{helper}{TotalWithdrawalCount});
      $hash->{helper}{TotalWaterConsumption}                  = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalWaterConsumption", $hash->{helper}{TotalWaterConsumption});
      $hash->{helper}{TotalHotWaterShare}                     = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalHotWaterShare", $hash->{helper}{TotalHotWaterShare});
      $hash->{helper}{TotalWaterCost}                         = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalWaterCost", $hash->{helper}{TotalWaterCost});
      $hash->{helper}{TotalEnergyCost}                        = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TotalEnergyCost", $hash->{helper}{TotalEnergyCost});
  
      $hash->{helper}{TodayAnalyzeStartTimestamp}             = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayAnalyzeStartTimestamp", $hash->{helper}{TodayAnalyzeStartTimestamp});
      $hash->{helper}{TodayAnalyzeEndTimestamp}               = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayAnalyzeEndTimestamp", $hash->{helper}{TodayAnalyzeEndTimestamp});
      $hash->{helper}{TodayWithdrawalCount}                   = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayWithdrawalCount", $hash->{helper}{TodayWithdrawalCount});
      $hash->{helper}{TodayWaterConsumption}                  = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayWaterConsumption", $hash->{helper}{TodayWaterConsumption});
      $hash->{helper}{TodayHotWaterShare}                     = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayHotWaterShare", $hash->{helper}{TodayHotWaterShare});
      $hash->{helper}{TodayWaterCost}                         = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayWaterCost", $hash->{helper}{TodayWaterCost});
      $hash->{helper}{TodayEnergyCost}                        = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayEnergyCost", $hash->{helper}{TodayEnergyCost});
      $hash->{helper}{TodayMaxFlowrate}                       = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "TodayMaxFlowrate", $hash->{helper}{TodayMaxFlowrate});
    }

    CommandAttr(undef, $name . " stateFormat " . $SenseGuard_DefaultStateFormat)
      if(AttrVal($name, "stateFormat", "none") eq "none" and
        $SenseGuard_DefaultStateFormat ne "");

    CommandAttr(undef, $name . " webCmd " . $SenseGuard_DefaultWebCmdFormat)
      if( AttrVal($name, "webCmd", "none") eq "none" and
        $SenseGuard_DefaultWebCmdFormat ne "");
  }
  ### sense
  elsif( $model eq "sense" )
  {
    # the Sense devices update just once a day
    $hash->{".DEFAULTINTERVAL"}             = $Sense_DefaultInterval;
    $hash->{".DEFAULTGETTIMESPAN"}  = $Sense_DefaultGetTimespan;
    $hash->{".AttrList"} = 
      $GroheOndusSmartDevice_AttrList .
      $GroheOndusSmartDevice_Sense_AttrList . 
      $readingFnAttributes;

    $hash->{helper}{Telegram_GetConfigCounter}    = 0;
    $hash->{helper}{Telegram_GetStateCounter}     = 0;
    $hash->{helper}{Telegram_GetDataCounter}      = 0;

    # set defaults
    $hash->{helper}{GetSuspendReadings}           = "0";
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";

    if($init_done)
    {
      # device is created *after* fhem has started -> don't restore old values
      Log3($name, 5, "GroheOndusSmartDevice_Define($name) - device is created after fhem has started -> don't restore old values");
    }
    else
    {
      # device is created *while* fhem is starting -> restore old values
      Log3($name, 5, "GroheOndusSmartDevice_Define($name) - device is created while fhem is starting -> restore old values");

      $hash->{helper}{GetSuspendReadings}           = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});
      $hash->{helper}{LastProcessedTimestamp_LUTC}  = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "LastProcessedTimestamp_LUTC", $hash->{helper}{LastProcessedTimestamp_LUTC});
    }

    CommandAttr(undef, $name . " stateFormat " . $Sense_DefaultStateFormat)
      if( AttrVal($name, "stateFormat", "none" ) eq "none" and
        $Sense_DefaultStateFormat ne "");

    CommandAttr(undef, $name . " webCmd " . $Sense_DefaultWebCmdFormat)
      if(AttrVal($name, "webCmd", "none") eq "none" and
        $Sense_DefaultWebCmdFormat ne "");
  }
  ### blue
  elsif( $model eq "blue" )
  {
    # the Sense devices update just once a day
    $hash->{".DEFAULTINTERVAL"}     = $Blue_DefaultInterval;
    $hash->{".DEFAULTGETTIMESPAN"}  = $Blue_DefaultGetTimespan;
    $hash->{".AttrList"} = 
      $GroheOndusSmartDevice_AttrList .
      $GroheOndusSmartDevice_Blue_AttrList . 
      $readingFnAttributes;

    $hash->{helper}{Telegram_GetConfigCounter}    = 0;
    $hash->{helper}{Telegram_GetStateCounter}     = 0;
    $hash->{helper}{Telegram_GetDataCounter}      = 0;

    # set defaults
    $hash->{helper}{GetSuspendReadings}           = "0";
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";

    if($init_done)
    {
      # device is created *after* fhem has started -> don't restore old values
      Log3($name, 5, "GroheOndusSmartDevice_Define($name) - device is created after fhem has started -> don't restore old values");
    }
    else
    {
      # device is created *while* fhem is starting -> restore old values
      Log3($name, 5, "GroheOndusSmartDevice_Define($name) - device is created while fhem is starting -> restore old values");

      $hash->{helper}{GetSuspendReadings}           = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});
      $hash->{helper}{LastProcessedTimestamp_LUTC}  = GroheOndusSmartDevice_Restore( $hash, "GroheOndusSmartDevice_Define", "LastProcessedTimestamp_LUTC", $hash->{helper}{LastProcessedTimestamp_LUTC});
    }

    CommandAttr(undef, $name . " stateFormat " . $Blue_DefaultStateFormat)
      if( AttrVal($name, "stateFormat", "none" ) eq "none" and
        $Blue_DefaultStateFormat ne "");

    CommandAttr(undef, $name . " webCmd " . $Blue_DefaultWebCmdFormat)
      if(AttrVal($name, "webCmd", "none") eq "none" and
        $Blue_DefaultWebCmdFormat ne "");
  }  
  else
  {
    return "unknown model $model"
  }

  $hash->{DEVICEID}                                     = $deviceId;
  $hash->{ApplianceModel}                               = $model;
  $hash->{VERSION}                                      = $VERSION;
  $hash->{NOTIFYDEV}                                    = "global,$name,$bridge";
  $hash->{RETRIES}                                      = 3;
  $hash->{DataTimerInterval}                            = $hash->{".DEFAULTINTERVAL"};
  $hash->{helper}{DEBUG}                                = "0";
  $hash->{helper}{IsDisabled}                           = "0";
  $hash->{helper}{OverrideCheckTDT}                     = "0";
  $hash->{helper}{ApplianceTDT_LUTC}                    = "";
  $hash->{helper}{ApplianceTDT_LUTC_GetData}            = "";
  $hash->{helper}{LogFileEnabled}                       = "1";
  $hash->{helper}{LogFilePattern}                       = $DefaultLogfilePattern;
  $hash->{helper}{LogFileName}                          = undef;
  $hash->{helper}{LogFileFormat}                        = $DefaultLogfileFormat;
  $hash->{helper}{LogFileGetDataStartDate_LTZ}          = "";
  $hash->{helper}{GetTimespan}                          = $hash->{".DEFAULTGETTIMESPAN"};
  $hash->{helper}{GetInProgress}                        = "0";
  $hash->{helper}{GetCampain}                           = 0;

  AssignIoPort( $hash, $bridge );

  my $iodev = $hash->{IODev}->{NAME};

  my $d = $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

  return "GroheOndusSmartDevice device $name on GroheOndusSmartBridge $iodev already defined."
    if(defined($d) and 
      $d->{IODev} == $hash->{IODev} and 
      $d->{NAME} ne $name );

  # ensure attribute room is present
  if(AttrVal($name, "room", "none") eq "none")
  {
    my $room = AttrVal($iodev, "room", "GroheOndusSmart");
    CommandAttr(undef, $name . " room " . $room);
  }
  
  # ensure attribute inerval is present
  if(AttrVal($name, "interval", "none") eq "none")
  {
    CommandAttr(undef, $name . " interval " . $hash->{DataTimerInterval})
  }

  Log3($name, 3, "GroheOndusSmartDevice_Define($name) - defined GroheOndusSmartDevice with DEVICEID: $deviceId");

  readingsSingleUpdate($hash, "state", "initialized", 1);

  $modules{GroheOndusSmartDevice}{defptr}{$deviceId} = $hash;

  # remove marker value
  $hash->{helper}{DefineRunning} = undef;

  return undef;
}

#####################################
# GroheOndusSmartDevice_Undef( $hash, $arg )
sub GroheOndusSmartDevice_Undef($$)
{
  my ( $hash, $arg ) = @_;
  my $name     = $hash->{NAME};
  my $deviceId = $hash->{DEVICEID};

  Log3($name, 4, "GroheOndusSmartDevice_Undef($name)");

  GroheOndusSmartDevice_TimerRemove($hash);
  GroheOndusSmartDevice_Blue_GetData_TimerRemove($hash);
  GroheOndusSmartDevice_Sense_GetData_TimerRemove($hash);
  GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($hash);

  delete $modules{GroheOndusSmartDevice}{defptr}{$deviceId};

  return undef;
}

#####################################
# GroheOndusSmartDevice_Delete( $hash, $name )
sub GroheOndusSmartDevice_Delete($$)
{
  my ( $hash, $name ) = @_;

  Log3($name, 4, "GroheOndusSmartDevice_Delete($name)");

  # delete all stored values
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "LastProcessedTimestamp_LUTC", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "LastProcessedWithdrawalTimestamp_LUTC", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "GetSuspendReadings", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalAnalyzeStartTimestamp", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalAnalyzeEndTimestamp", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalWithdrawalCount", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalWaterConsumption", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalHotWaterShare", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalWaterCost", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TotalEnergyCost", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayAnalyzeStartTimestamp", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayAnalyzeEndTimestamp", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayWithdrawalCount", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayWaterConsumption", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayHotWaterShare", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayWaterCost", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayEnergyCost", undef);
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Delete", "TodayMaxFlowrate", undef);

  return undef;
}

#####################################
# GroheOndusSmartDevice_Rename($new_name, $old_name)
sub GroheOndusSmartDevice_Rename($$)
{
  my ($new_name, $old_name) = @_;
  my $hash = $defs{$new_name};
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartDevice_Rename($name)");

  # rename all stored values
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "LastProcessedTimestamp_LUTC");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "LastProcessedWithdrawalTimestamp_LUTC");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "GetSuspendReadings");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalAnalyzeStartTimestamp");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalAnalyzeEndTimestamp");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalWithdrawalCount");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalWaterConsumption");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalHotWaterShare");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalWaterCost");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TotalEnergyCost");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayAnalyzeStartTimestamp");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayAnalyzeEndTimestamp");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayWithdrawalCount");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayWaterConsumption");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayHotWaterShare");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayWaterCost");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayEnergyCost");
  GroheOndusSmartDevice_StoreRename($hash, "GroheOndusSmartDevice_Rename", $old_name, "TodayMaxFlowrate");

  return undef;
}

#####################################
# GroheOndusSmartDevice_Attr( $cmd, $name, $attrName, $attrVal )
sub GroheOndusSmartDevice_Attr(@)
{
  my ( $cmd, $name, $attrName, $attrVal ) = @_;
  my $hash = $defs{$name};

  Log3($name, 4, "GroheOndusSmartDevice_Attr($name) - $attrName was called");

  # Attribute "disable"
  if( $attrName eq "disable" )
  {
    if( $cmd eq "set" and 
      $attrVal eq "1" )
    {
      $hash->{helper}{IsDisabled} = "1";

      GroheOndusSmartDevice_TimerRemove($hash);
      GroheOndusSmartDevice_Sense_GetData_TimerRemove($hash);
      GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($hash);

      readingsSingleUpdate( $hash, "state", "inactive", 1 );
      Log3($name, 3, "GroheOndusSmartDevice($name) - disabled");
    } 
    else
    {
      $hash->{helper}{IsDisabled} = "0";

      readingsSingleUpdate( $hash, "state", "active", 1 );

      GroheOndusSmartDevice_TimerExecute($hash)
        if($init_done and
          not $hash->{helper}{DefineRunning});
      Log3($name, 3, "GroheOndusSmartDevice($name) - enabled");
    }
  }

  # Attribute "interval"
  elsif( $attrName eq "interval" )
  {
    # onchange event for attribute "interval" is handled in sub "Notify" -> calls "updateValues" -> Timer is reloaded
    if($cmd eq "set")
    {
      return "Interval must be greater than 0"
        unless($attrVal > 0);

      $hash->{DataTimerInterval} = $attrVal;

      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - set interval: $attrVal");
    } 
    elsif($cmd eq "del")
    {
      $hash->{DataTimerInterval} = $hash->{".DEFAULTINTERVAL"};

      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - delete interval and set default: 60");
    }

    GroheOndusSmartDevice_TimerExecute($hash)
      if($init_done and
        not $hash->{helper}{DefineRunning});
  }

  # Attribute "debug"
  elsif($attrName eq "debug")
  {
    if($cmd eq "set")
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - debugging enabled");

      $hash->{helper}{DEBUG} = "$attrVal";
      GroheOndusSmartDevice_UpdateInternals($hash);
    } 
    elsif($cmd eq "del")
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - debugging disabled");

      $hash->{helper}{DEBUG} = "0";
      GroheOndusSmartDevice_UpdateInternals($hash);
    }
  }

  # Attribute "offsetTotalWaterCost"
  elsif($attrName eq "offsetTotalWaterCost")
  {
    if($cmd eq "set")
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetTotalWaterCost: $attrVal");

      $hash->{helper}{TotalWaterCost} -= $hash->{helper}{OffsetWaterCost};
      $hash->{helper}{OffsetWaterCost} = $attrVal;
      $hash->{helper}{TotalWaterCost} += $hash->{helper}{OffsetWaterCost};
    } 
    elsif($cmd eq "del")
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - delete offsetTotalWaterCost and set default: 0");

      $hash->{helper}{TotalWaterCost} -= $hash->{helper}{OffsetWaterCost};
      $hash->{helper}{OffsetWaterCost} = 0;
    }

    GroheOndusSmartDevice_UpdateInternals($hash);
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalWaterCost", $hash->{helper}{TotalWaterCost});
    readingsSingleUpdate($hash, "TotalWaterCost", $hash->{helper}{TotalWaterCost}, 1);
  }
  
  # Attribute "offsetTotalHotWaterShare"
  elsif($attrName eq "offsetTotalHotWaterShare")
  {
    if($cmd eq "set")
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetTotalHotWaterShare: $attrVal");

      $hash->{helper}{TotalHotWaterShare} -= $hash->{helper}{OffsetHotWaterShare};
      $hash->{helper}{OffsetHotWaterShare} = $attrVal;
      $hash->{helper}{TotalHotWaterShare} += $hash->{helper}{OffsetHotWaterShare};
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - delete offsetTotalHotWaterShare and set default: 0");

      $hash->{helper}{TotalHotWaterShare} -= $hash->{helper}{OffsetHotWaterShare};
      $hash->{helper}{OffsetHotWaterShare} = 0;
    }

    GroheOndusSmartDevice_UpdateInternals($hash);
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalHotWaterShare", $hash->{helper}{TotalHotWaterShare});
    readingsSingleUpdate($hash, "TotalHotWaterShare", $hash->{helper}{TotalHotWaterShare}, 1);
  }
  
  # Attribute "offsetTotalEnergyCost"
  elsif( $attrName eq "offsetTotalEnergyCost" )
  {
    if( $cmd eq "set" )
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetTotalEnergyCost: $attrVal");

      $hash->{helper}{TotalEnergyCost} -= $hash->{helper}{OffsetEnergyCost};
      $hash->{helper}{OffsetEnergyCost} = $attrVal;
      $hash->{helper}{TotalEnergyCost} += $hash->{helper}{OffsetEnergyCost};
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - delete offsetTotalEnergyCost and set default: 0");

      $hash->{helper}{TotalEnergyCost} -= $hash->{helper}{OffsetEnergyCost};
      $hash->{helper}{OffsetEnergyCost} = 0;
    }

    GroheOndusSmartDevice_UpdateInternals($hash);
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalEnergyCost", $hash->{helper}{TotalEnergyCost});
    readingsSingleUpdate($hash, "TotalEnergyCost", $hash->{helper}{TotalEnergyCost}, 1);
  }
  
  # Attribute "offsetTotalWaterConsumption"
  elsif( $attrName eq "offsetTotalWaterConsumption" )
  {
    if( $cmd eq "set" )
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - set offsetTotalWaterConsumption: $attrVal");

      $hash->{helper}{TotalWaterConsumption} -= $hash->{helper}{OffsetWaterConsumption};
      $hash->{helper}{OffsetWaterConsumption} = $attrVal;
      $hash->{helper}{TotalWaterConsumption} += $hash->{helper}{OffsetWaterConsumption};
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartDevice_Attr($name) - delete offsetTotalWaterConsumption and set default: 0");

      $hash->{helper}{TotalWaterConsumption} -= $hash->{helper}{OffsetWaterConsumption};
      $hash->{helper}{OffsetWaterConsumption} = 0;
    }

    GroheOndusSmartDevice_UpdateInternals($hash);
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalWaterConsumption", $hash->{helper}{TotalWaterConsumption});
    readingsSingleUpdate($hash, "TotalWaterConsumption", $hash->{helper}{TotalWaterConsumption}, 1);
  }

  # Attribute "logFileEnabled"
  elsif( $attrName eq "logFileEnabled" )
  {
    if( $cmd eq "set")
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - logFileEnabled $attrVal");

      $hash->{helper}{LogFileEnabled} = "$attrVal";
      GroheOndusSmartDevice_UpdateInternals($hash);
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - logFileEnabled disabled");

      $hash->{helper}{LogFileEnabled} = "0";
      GroheOndusSmartDevice_UpdateInternals($hash);
    }
  }

  # Attribute "logFilePattern"
  elsif( $attrName eq "logFilePattern" )
  {
    if( $cmd eq "set" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - logFilePattern $attrVal");

      $hash->{helper}{LogFilePattern} = "$attrVal";
      GroheOndusSmartDevice_UpdateInternals($hash);
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - delete logFilePattern and set default");

      $hash->{helper}{LogFilePattern} = $DefaultLogfilePattern;
      GroheOndusSmartDevice_UpdateInternals($hash);
    }
  }

  # Attribute "logFileFormat"
  elsif( $attrName eq "logFileFormat" )
  {
    if( $cmd eq "set" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - logFileFormat $attrVal");

      $hash->{helper}{LogFileFormat} = "$attrVal";
      GroheOndusSmartDevice_UpdateInternals($hash);
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - delete logFileFormat and set default");

      $hash->{helper}{LogFileFormat} = $DefaultLogfileFormat;
      GroheOndusSmartDevice_UpdateInternals($hash);
    }
  }

  # Attribute "logFileGetDataStartDate"
  elsif( $attrName eq "logFileGetDataStartDate" )
  {
    if( $cmd eq "set" )
    {
      # parse value and try to expand to full format
      my $timestampLocal_s = str2time($attrVal);
      my @t = localtime($timestampLocal_s);
      my $timestamp = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
      
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - logFileGetDataStartDate $timestamp");

      $hash->{helper}{LogFileGetDataStartDate_LTZ} = "$timestamp";
      GroheOndusSmartDevice_UpdateInternals($hash);
    } 
    elsif( $cmd eq "del" )
    {
      Log3($name, 3, "GroheOndusSmartBridge_Attr($name) - delete logFileGetDataStartDate and set default");

      $hash->{helper}{LogFileGetDataStartDate_LTZ} = "";
      GroheOndusSmartDevice_UpdateInternals($hash);
    }
  }

  return undef;
}

#####################################
# GroheOndusSmartDevice_Notify( $hash, $dev )
sub GroheOndusSmartDevice_Notify($$)
{
  my ($hash, $dev)  = @_;
  my $name          = $hash->{NAME};

  return
    if($hash->{helper}{IsDisabled} ne "0");

  my $devname = $dev->{NAME};
  my $devtype = $dev->{TYPE};
  my $events  = deviceEvents( $dev, 1 );

  return
    if(!$events);

  Log3($name, 4, "GroheOndusSmartDevice_Notify($name) - DevType: \"$devtype\"");

  # process "global" events
  if($devtype eq "Global")
  {
    # global Initialization is done
    if(grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
    {
      Log3($name, 3, "GroheOndusSmartDevice_Notify($name) - global event INITIALIZED was catched");

      GroheOndusSmartDevice_Upgrade($hash);
    }
  }
  
  # process events from Bridge
  elsif( $devtype eq "GroheOndusSmartBridge" )
  {
    if(grep /^state:.*$/, @{$events})
    {
      my $ioDeviceState =  ReadingsVal($hash->{IODev}->{NAME}, "state", "none");
      
      Log3($name, 4, "GroheOndusSmartDevice_Notify($name) - event \"state: $ioDeviceState\" from GroheOndusSmartBridge was catched");

      if($ioDeviceState eq "connected to cloud")
      {
      }
      else
      {
        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged($hash, "state", "bridge " . $ioDeviceState, 1);
        readingsEndUpdate($hash, 1);
      }
    }
    else
    {
      Log3($name, 4, "GroheOndusSmartDevice_Notify($name) - event from GroheOndusSmartBridge was catched");
    }
  }
  
  # process internal events
  elsif($devtype eq "GroheOndusSmartDevice")
  {
  }

  return;
}

#####################################
# GroheOndusSmartDevice_Set( $hash, $name, $cmd, @args )
sub GroheOndusSmartDevice_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  my $payload;
  my $model = $hash->{ApplianceModel};

  Log3($name, 4, "GroheOndusSmartDevice_Set($name): cmd= $cmd");

  #########################################################
  ### sense_guard #########################################
  #########################################################
  if( $model eq "sense_guard" )
  {
    return GroheOndusSmartDevice_SenseGuard_Set($hash, $name, $cmd, @args);
  }
  #########################################################
  ### sense ###############################################
  #########################################################
  elsif( $model eq "sense" )
  {
    return GroheOndusSmartDevice_Sense_Set($hash, $name, $cmd, @args);
  }
  #########################################################
  ### blue ################################################
  #########################################################
  elsif( $model eq "blue" )
  {
    return GroheOndusSmartDevice_Sense_Set($hash, $name, $cmd, @args);
  }
  ### unknown ###
  else
  {
    return "Unknown model \"$model\"";
  }
}

#####################################
# GroheOndusSmartDevice_Parse( $io_hash, $match )
sub GroheOndusSmartDevice_Parse($$)
{
  my ($io_hash, $match) = @_;
  my $io_name = $io_hash->{NAME};

  # to pass parameters to this underlying logical device
  # the hash "currentAppliance" is set in io_hash for the moment
  my $current_appliance_id  = $io_hash->{currentAppliance}->{appliance_id};
  my $current_type_id       = $io_hash->{currentAppliance}->{type_id};
  my $current_name          = $io_hash->{currentAppliance}->{name};
  my $current_location_id   = $io_hash->{currentAppliance}->{location_id};
  my $current_room_id       = $io_hash->{currentAppliance}->{room_id};
  my $autocreate            = $io_hash->{currentAppliance}->{autocreate};

  # replace "umlaute"
  $current_name =~ s/($replacechartablekeys)/$replacechartable{$1}/g;

  Log3($io_name, 4, "GroheOndusSmartBridge($io_name) -> GroheOndusSmartDevice_Parse");

  if(defined( $current_appliance_id ))
  {
    # SmartDevice with $deviceId found:
    if(my $hash = $modules{GroheOndusSmartDevice}{defptr}{$current_appliance_id})
    {
      my $name = $hash->{NAME};

      Log3($name, 5, "GroheOndusSmartDevice_Parse($name) - found logical device");

      # set internals
      $hash->{ApplianceId}          = $current_appliance_id;
      $hash->{ApplianceTypeId}      = $current_type_id;
      $hash->{ApplianceLocationId}  = $current_location_id;
      $hash->{ApplianceRoomId}      = $current_room_id;

      if($hash->{helper}{GetInProgress} eq "0")
      {
        # change state to "connected to cloud" -> Notify -> load timer
        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged( $hash, "state", "connected over bridge to cloud", 1 );
        readingsEndUpdate( $hash, 1 );
      }

      # if not timer is running then start one
      if(not defined( $hash->{DataTimerNext}) or
        $hash->{DataTimerNext} eq "none")
      {
        GroheOndusSmartDevice_TimerExecute($hash);
      }

      return $name;
    }

    # SmartDevice not found, create new one
    elsif($autocreate eq "1")
    {
      my $deviceName = makeDeviceName($current_name);
      
      if( $current_type_id == 101 )
      {
        my $deviceTypeName = "sense";
        Log3($io_name, 3, "GroheOndusSmartBridge($io_name) -> autocreate new device $deviceName with applianceId $current_appliance_id, model $deviceTypeName");

        return "UNDEFINED $deviceName GroheOndusSmartDevice $io_name $current_appliance_id $deviceTypeName";
      } 
      elsif( $current_type_id == 103 )
      {
        my $deviceTypeName = "sense_guard";
        Log3($io_name, 3, "GroheOndusSmartBridge($io_name) -> autocreate new device $deviceName with applianceId $current_appliance_id, model $deviceTypeName");

        return "UNDEFINED $deviceName GroheOndusSmartDevice $io_name $current_appliance_id $deviceTypeName";
      } 
      elsif( $current_type_id == 104 )
      {
        my $deviceTypeName = "blue";
        Log3($io_name, 3, "GroheOndusSmartBridge($io_name) -> autocreate new device $deviceName with applianceId $current_appliance_id, model $deviceTypeName");

        return "UNDEFINED $deviceName GroheOndusSmartDevice $io_name $current_appliance_id $deviceTypeName";
      } 
      else
      {
        Log3($io_name, 3, "GroheOndusSmartBridge($io_name) - can't find matching devicetype");

        return undef;
      }
    }
  }
}

##################################
# GroheOndusSmartDevice_Upgrade( $hash )
sub GroheOndusSmartDevice_Upgrade($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  # delete deprecated attribute "IODev"
  if( AttrVal( $name, "IODev", "none" ) ne "none" )
  {
    Log3($name, 3, "GroheOndusSmartDevice_Upgrade($name) - deleting old attribute IODEV");
    fhem("deleteattr $name IODev", 1);
  }

  # delete deprecated attribute "model"
  if( AttrVal( $name, "model", "none" ) ne "none" )
  {
    Log3($name, 3, "GroheOndusSmartDevice_Upgrade($name) - deleting old attribute model");
    fhem("deleteattr $name model", 1);
  }
}

#####################################
# GroheOndusSmartDevice_UpdateInternals( $hash )
# This methode copies values from $hash-{helper} to visible internals 
sub GroheOndusSmartDevice_UpdateInternals($)
{
  my ( $hash ) = @_;
  my $name  = $hash->{NAME};
  my $model = $hash->{ApplianceModel};

  Log3($name, 5, "GroheOndusSmartDevice_UpdateInternals($name)");

  # logFile internals
  if($hash->{helper}{LogFileEnabled} eq "1")
  {
    $hash->{LogFile_Pattern}  = $hash->{helper}{LogFilePattern};
    $hash->{LogFile_Name}     = $hash->{helper}{LogFileName};
  }
  else
  {
    # delete all keys starting with "DEBUG_"
    my @matching_keys =  grep /LogFile_/, keys %$hash;
    foreach (@matching_keys)
    {
      delete $hash->{$_};
    }
  }
  
  # debug-internals
  if($hash->{helper}{DEBUG} eq "1")
  {
    $hash->{DEBUG_IsDisabled}                             = $hash->{helper}{IsDisabled};
    $hash->{DEBUG_ApplianceTDT_LUTC}                      = $hash->{helper}{ApplianceTDT_LUTC};
    $hash->{DEBUG_ApplianceTDT_LUTC_GetData}              = $hash->{helper}{ApplianceTDT_LUTC_GetData};
    $hash->{DEBUG_OverrideCheckTDT}                       = $hash->{helper}{OverrideCheckTDT};
    $hash->{DEBUG_LastProcessedTimestamp_LUTC}            = $hash->{helper}{LastProcessedTimestamp_LUTC};

    $hash->{DEBUG_LogFileEnabled}                         = $hash->{helper}{LogFileEnabled};
    $hash->{DEBUG_LogFilePattern}                         = $hash->{helper}{LogFilePattern};
    $hash->{DEBUG_LogFileName}                            = $hash->{helper}{LogFileName};
    $hash->{DEBUG_LogFileFormat}                          = $hash->{helper}{LogFileFormat};
    $hash->{DEBUG_LogFileGetDataStartDate_LTZ}            = $hash->{helper}{LogFileGetDataStartDate_LTZ};
    
    $hash->{DEBUG_GetInProgress}                          = $hash->{helper}{GetInProgress};
    $hash->{DEBUG_GetTimespan}                            = $hash->{helper}{GetTimespan};
    $hash->{DEBUG_GetCampain}                             = $hash->{helper}{GetCampain};
    $hash->{DEBUG_GetSuspendReadings}                     = $hash->{helper}{GetSuspendReadings};
    
    if($model eq "sense_guard")
    {
      $hash->{DEBUG_LastProcessedWithdrawalTimestamp_LUTC}  = $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC};

      $hash->{DEBUG_OffsetEnergyCost}                       = $hash->{helper}{OffsetEnergyCost};
      $hash->{DEBUG_OffsetWaterCost}                        = $hash->{helper}{OffsetWaterCost};
      $hash->{DEBUG_OffsetWaterConsumption}                 = $hash->{helper}{OffsetWaterConsumption}; 
      $hash->{DEBUG_OffsetHotWaterShare}                    = $hash->{helper}{OffsetHotWaterShare};
  
      $hash->{DEBUG_TotalAnalyzeStartTimestamp}             = $hash->{helper}{TotalAnalyzeStartTimestamp};
      $hash->{DEBUG_TotalAnalyzeEndTimestamp}               = $hash->{helper}{TotalAnalyzeEndTimestamp};
      $hash->{DEBUG_TotalWithdrawalCount}                   = $hash->{helper}{TotalWithdrawalCount};
      $hash->{DEBUG_TotalWaterConsumption}                  = $hash->{helper}{TotalWaterConsumption};
      $hash->{DEBUG_TotalHotWaterShare}                     = $hash->{helper}{TotalHotWaterShare};
      $hash->{DEBUG_TotalWaterCost}                         = $hash->{helper}{TotalWaterCost};
      $hash->{DEBUG_TotalEnergyCost}                        = $hash->{helper}{TotalEnergyCost};
  
      $hash->{DEBUG_TodayAnalyzeStartTimestamp}             = $hash->{helper}{TodayAnalyzeStartTimestamp};
      $hash->{DEBUG_TodayAnalyzeEndTimestamp}               = $hash->{helper}{TodayAnalyzeEndTimestamp};
      $hash->{DEBUG_TodayWithdrawalCount}                   = $hash->{helper}{TodayWithdrawalCount};
      $hash->{DEBUG_TodayWaterConsumption}                  = $hash->{helper}{TodayWaterConsumption};
      $hash->{DEBUG_TodayHotWaterShare}                     = $hash->{helper}{TodayHotWaterShare};
      $hash->{DEBUG_TodayWaterCost}                         = $hash->{helper}{TodayWaterCost};
      $hash->{DEBUG_TodayEnergyCost}                        = $hash->{helper}{TodayEnergyCost};
      $hash->{DEBUG_TodayMaxFlowrate}                       = $hash->{helper}{TodayMaxFlowrate};
    }
    elsif($model eq "sense")
    {
    }
    elsif($model eq "blue")
    {
    }

    my @retrystring_keys =  grep /Telegram_/, keys %{$hash->{helper}};
    foreach (@retrystring_keys)
    {
      $hash->{"DEBUG_" . $_} = $hash->{helper}{$_};
    }
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

##################################
# GroheOndusSmartDevice_TimerExecute( $hash )
sub GroheOndusSmartDevice_TimerExecute($)
{
  my ( $hash )  = @_;
  my $name      = $hash->{NAME};
  my $interval  = $hash->{DataTimerInterval};
  my $model     = $hash->{ApplianceModel};

  GroheOndusSmartDevice_TimerRemove($hash);

  if($init_done and 
    $hash->{helper}{IsDisabled} eq "0" )
  {
    Log3($name, 4, "GroheOndusSmartDevice_TimerExecute($name)");

    ### sense ###
    if( $model eq "sense" )
    {
      GroheOndusSmartDevice_Sense_Update($hash);
    }
    ### sense_guard ###
    elsif( $model eq "sense_guard" )
    {
      GroheOndusSmartDevice_SenseGuard_Update($hash);
    }
    ### blue ###
    elsif( $model eq "blue" )
    {
      GroheOndusSmartDevice_Blue_Update($hash);
    }

    # reload timer
    my $nextTimer = gettimeofday() + $interval;
    $hash->{DataTimerNext} = strftime($TimeStampFormat, localtime($nextTimer));
    InternalTimer($nextTimer, "GroheOndusSmartDevice_TimerExecute", $hash);
  } 
  else
  {
    readingsSingleUpdate($hash, "state", "disabled", 1);

    Log3($name, 4, "GroheOndusSmartDevice_TimerExecute($name) - device is disabled");
  }
}

##################################
# GroheOndusSmartDevice_TimerRemove( $hash )
sub GroheOndusSmartDevice_TimerRemove($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartDevice_TimerRemove($name)");

  $hash->{DataTimerNext} = "none";
  RemoveInternalTimer($hash, "GroheOndusSmartDevice_TimerExecute");
}

##################################
# GroheOndusSmartDevice_IOWrite( $hash, $param )
sub GroheOndusSmartDevice_IOWrite($$)
{
  my ( $hash, $param ) = @_;
  my $name = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartDevice_IOWrite($name)");

  IOWrite( $hash, $param );
}

##################################
# GroheOndusSmartDevice_SenseGuard_Update( $hash )
sub GroheOndusSmartDevice_SenseGuard_Update($)
{
  my ( $hash ) = @_;
  my $name     = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_Update($name)");

  # parallel call:
  #GroheOndusSmartDevice_SenseGuard_GetData_Last($hash);
  #GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($hash);
  #GroheOndusSmartDevice_SenseGuard_GetState($hash);
  #GroheOndusSmartDevice_SenseGuard_GetConfig($hash);
  
  # serial call:
  my $getData             = sub { GroheOndusSmartDevice_SenseGuard_GetData_Last($hash); };
  my $getApplianceCommand = sub { GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($hash, $getData); };
  my $getState            = sub { GroheOndusSmartDevice_SenseGuard_GetState($hash, $getApplianceCommand); };
  my $getConfig           = sub { GroheOndusSmartDevice_SenseGuard_GetConfig($hash, $getState); };
  
  $getConfig->();
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetState( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetState($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};
  my $modelId = 103;

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetStateTimeRequest} = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetStateCallback}    = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "State_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };

      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetState($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "State_JSON_ERROR", $@, 1 );
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
        if( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          foreach my $currentData ( @{ $decode_json } )
          {
            if( $currentData->{type} eq "update_available"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateUpdateAvailable", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "connection"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateConnection", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "wifi_quality"
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

          $hash->{helper}{Telegram_GetStateCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }

        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetStateTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/status";
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_GetStateIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetState($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetConfig( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetConfig($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetConfigTimeRequest} = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetConfigCallback}    = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "Config_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "Config_JSON_ERROR", $@, 1 );
        }
        $errorMsg = "GETConfig_JSON_ERROR";
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
      
        if( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
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

          if( defined( $currentEntry )
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

            $hash->{helper}{ApplianceTDT_LUTC} = "$currentEntry->{tdt}"
              if( defined( $currentEntry->{tdt} ) );

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

            if( defined( $currentConfig )
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

              if( defined( $currentThresholds ) and
                ref( $currentThresholds ) eq "ARRAY" )
              {
                foreach my $currentThreshold ( @{ $currentThresholds} )
                {
                  if( "$currentThreshold->{quantity}" eq "flowrate" )
                  {
                    if( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigFlowrateThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigFlowrateThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  } 
                  elsif( "$currentThreshold->{quantity}" eq "pressure" )
                  {
                    if( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigPressureThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigPressureThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  }
                  elsif( "$currentThreshold->{quantity}" eq "temperature_guard" )
                  {
                    if( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  }
                }
              }
            }
          }

          $hash->{helper}{Telegram_GetConfigCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetConfigTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_GetConfigIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetConfig($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetData( $hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetData($$;$$)
{
  my ( $hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetDataTimeRequest}  = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetDataCallback}     = strftime($TimeStampFormat, localtime($stopwatch));

    Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - resultCallback");

    my $lastProcessedWithdrawalTimestamp_LUTC = $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC};
    my $lastProcessedTimestamp_LUTC           = $hash->{helper}{LastProcessedTimestamp_LUTC};

    my $currentDataTimestamp_LUTC             = undef;
    my $currentDataFlowrate                   = undef;
    my $currentDataPressure                   = undef;
    my $currentDataTemperature                = undef;

    my $currentWithdrawalTimestampStart_LUTC  = undef;
    my $currentWithdrawalTimestampStop_LUTC   = undef;
    my $currentWithdrawalDuration             = undef;
    my $currentWithdrawalConsumption          = undef;
    my $currentWithdrawalCostEnergy           = undef;
    my $currentWithdrawalCostWater            = undef;
    my $currentWithdrawalHotWaterShare        = undef;
    my $currentWithdrawalMaxFlowrate          = undef;

    if($callbackparam->{GetCampain} != $hash->{helper}{GetCampain})
    {
      $errorMsg = "GetData old Campain";
    }
    elsif( $errorMsg eq "" )
    {
      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "Data_RAW", "\"" . $data . "\"", 1 );
        readingsEndUpdate( $hash, 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetData($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, "Data_JSON_ERROR", $@, 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GetHistoricData_JSON_ERROR";
      }
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
      #         "hotWater_share":0,
      #         "waterconsumption":3.4,
      #         "stoptime":"2019-07-14T03:16:51.000+02:00",
      #         "starttime":"2019-07-14T03:16:24.000+02:00",
      #         "maxflowrate":10.7,
      #         "energy_cost":0
      #       },
      #       {
      #         "waterconsumption":7.6,
      #         "hotWater_share":0,
      #         "energy_cost":0,
      #         "starttime":"2019-07-14T03:58:19.000+02:00",
      #         "stoptime":"2019-07-14T03:59:13.000+02:00",
      #         "maxflowrate":10.9,
      #         "water_cost":0.032346
      #       }
      #     ]
      #   },
      # }
      elsif( defined( $decode_json->{data} ) and
        ref( $decode_json->{data} ) eq "HASH" )
      {
        $hash->{helper}{ApplianceTDT_LUTC_GetData} = $callbackparam->{ApplianceTDT_LUTC_GetData};

        my $totalValuesChanged = 0;
        my $todaysValuesChanged = 0;
        
        # this list contains all measurements-structures - format is:
        # $currentDataTimestamp_LTZ_s, $currentDataTimestamp_LUTC, $currentData
        my @measurementList;

        # this list contains all withdrawal-structures - format is:
        # $currentDataTimestampStart_LTZ_s, $currentDataTimestampStart_LUTC, $currentData
        my @withdrawalList;
        
        # Measurement
        #       {
        #         "timestamp":"2019-07-14T02:07:36.000+02:00",
        #         "flowrate":0,
        #         "temperature_guard":22.5,
        #         "pressure":3
        #       },
        if( defined( $decode_json->{data}->{measurement} ) and
          ref( $decode_json->{data}->{measurement} ) eq "ARRAY" )
        {
          my $loopCounter             = 0;
          my $listIsUnsorted          = 0; # if list isn't sorted by starttime by default: $listIsUnsorted != 0
          my $lastDataTimestamp_LTZ_s = 0;

          foreach my $currentData ( @{ $decode_json->{data}->{measurement} } )
          {
            # is this the correct dataset?
            if(defined($currentData->{timestamp}))
            {
              my $currentDataTimestamp_LUTC = $currentData->{timestamp};

              # extract the timestamp from UTC-string and get TimestampInSeconds
              my $currentDataTimestamp_LTZ   = GroheOndusSmartDevice_GetLTZFromLUTC($currentDataTimestamp_LUTC);
              my $currentDataTimestamp_LTZ_s = time_str2num($currentDataTimestamp_LTZ);

              # put current measurement in list
              push(@measurementList, [$currentDataTimestamp_LTZ_s, $currentDataTimestamp_LUTC, $currentData]);

              # sadly the datasets aren't sorted by starttime by default
              # so set $listIsUnsorted != 0 if list has to be sorted later
              if($currentDataTimestamp_LTZ_s < $lastDataTimestamp_LTZ_s)
              {
                $listIsUnsorted = 1;
              }
              $lastDataTimestamp_LTZ_s = $currentDataTimestamp_LTZ_s;
            }
            else
            {
              Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetData($name) - wrong Measurement dataset");
            }
            $loopCounter++;
          }
          $hash->{helper}{Telegram_GetDataLoopMeasurement} = $loopCounter;

          # sort list if necessary
          if($listIsUnsorted != 0)
          {
            Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - measurementlist has to be sorted");

            # the list isn't sorted by starttimestamp - so sort
            @measurementList = sort { $a->[0] cmp $b->[0] } @measurementList;
          }
          else
          {
            Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - measurementlist list is sorted");
          }
        }

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
        if( defined( $decode_json->{data}->{withdrawals} ) and
          ref( $decode_json->{data}->{withdrawals} ) eq "ARRAY" )
        {
          my $loopCounter             = 0;
          my $listIsUnsorted          = 0; # if list isn't sorted by starttime by default: $listIsUnsorted != 0
          my $lastDataTimestamp_LTZ_s = 0;

          foreach my $currentData ( @{ $decode_json->{data}->{withdrawals} } )
          {
            # is this the correct dataset?
            if( defined( $currentData->{starttime} ) and 
              defined( $currentData->{stoptime} ) 
            )
            {
              my $currentDataTimestampStart_LUTC = $currentData->{starttime};
              my $currentDataTimestampStop_LUTC  = $currentData->{stoptime};
              
              # extract the timestamp from UTC-string and get TimestampInSeconds
              my $currentDataTimestampStart_LTZ = GroheOndusSmartDevice_GetLTZFromLUTC($currentDataTimestampStart_LUTC);
              my $currentDataTimestampStart_LTZ_s = time_str2num($currentDataTimestampStart_LTZ);

              my $currentDataTimestampStop_LTZ = GroheOndusSmartDevice_GetLTZFromLUTC($currentDataTimestampStop_LUTC);
              my $currentDataTimestampStop_LTZ_s = time_str2num($currentDataTimestampStop_LTZ);
              
              my $currentDataDuration_s = $currentDataTimestampStop_LTZ_s - $currentDataTimestampStart_LTZ_s;
              $currentData->{duration}  = $currentDataDuration_s;                        # extend structure

              # put current measurement in list
              push(@withdrawalList, [$currentDataTimestampStart_LTZ_s, $currentDataTimestampStart_LUTC, $currentData]);
              
              # sadly the datasets aren't sorted by starttime by default
              # so set $listIsUnsorted != 0 if list has to be sorted later
              if($currentDataTimestampStart_LTZ_s < $lastDataTimestamp_LTZ_s)
              {
                $listIsUnsorted = 1;
              }
              $lastDataTimestamp_LTZ_s = $currentDataTimestampStart_LTZ_s;
            }
            else
            {
              Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetData($name) - wrong Withdrawal dataset");
            }
            $loopCounter++;
          }
          $hash->{helper}{Telegram_GetDataLoopWithdrawal} = $loopCounter;
          
          # sort list if necessary
          if($listIsUnsorted != 0)
          {
            Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - withdrawallist has to be sorted");

            # the list isn't sorted by starttimestamp - so sort
            @withdrawalList = sort { $a->[0] cmp $b->[0] } @withdrawalList;
          }
          else
          {
            Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - withdrawallist is sorted");
          }
        }

        # iterate through both lists:
        # "iterate a list if timestamp is smaller or equal than the timestamp of the other lists current dataset"
        # "break if no dataset is left"

        # get first datasets - undef if empty
        my $currentMeasurement = shift(@measurementList);
        my $currentWithdrawal = shift(@withdrawalList);

        my $todayMidnight_LTZ = GroheOndusSmartDevice_GetLTZMidnightDate();
        Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - midnight: $todayMidnight_LTZ");

        # get first entries of both lists if defined
        my ($currentMeasurementDataTimestamp_LTZ_s, $currentMeasurementDataTimestamp_LUTC, $currentMeasurementData) = @{$currentMeasurement}
          if(defined($currentMeasurement));
        my ($currentWithdrawalDataTimestamp_LTZ_s, $currentWithdrawalDataTimestamp_LUTC, $currentWithdrawalData) = @{$currentWithdrawal}
          if(defined($currentWithdrawal));
        
        while(defined($currentMeasurement) or # break loop if both entries are undefined
          defined($currentWithdrawal))
        {
          if(defined($currentMeasurement) and
            ((not defined($currentWithdrawal) or
            ($currentMeasurementDataTimestamp_LTZ_s <= $currentWithdrawalDataTimestamp_LTZ_s))))
          {
            # don't process measurevalues with timestamp before $lastProcessedTimestamp
            if($lastProcessedTimestamp_LUTC gt $currentMeasurementDataTimestamp_LUTC)
            {
              Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - old Measurement: $lastProcessedTimestamp_LUTC > $currentMeasurementDataTimestamp_LUTC");
            }
            else
            {
              $currentDataTimestamp_LUTC = $currentMeasurementData->{timestamp};
              $currentDataTemperature    = $currentMeasurementData->{temperature_guard};
              $currentDataPressure       = $currentMeasurementData->{pressure};
              $currentDataFlowrate       = $currentMeasurementData->{flowrate};

              # force the timestamp-seconds-string to have a well known length
              # fill with leading zeros
              my $currentDataTimestamp_LTZ_s_string = GroheOndusSmartDevice_GetLTZStringFromLUTC($currentDataTimestamp_LUTC);

              if( $hash->{helper}{GetSuspendReadings} eq "0")
              {
                readingsBeginUpdate($hash);
  
                readingsBulkUpdateIfChanged( $hash, "MeasurementDataTimestamp", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataTimestamp_LUTC )
                  if( defined($currentDataTimestamp_LUTC) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementFlowrate", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataFlowrate )
                  if( defined($currentDataFlowrate) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementTemperature", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataTemperature )
                  if( defined($currentDataTemperature) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementPressure", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataPressure )
                  if( defined($currentDataPressure) );
  
                readingsEndUpdate( $hash, 1 );
              }

              # if enabled write MeasureValues to own FileLog
              GroheOndusSmartDevice_FileLog_MeasureValueWrite($hash, "Measurement", $currentMeasurementDataTimestamp_LTZ_s, 
                  ["MeasurementDataTimestamp", $currentDataTimestamp_LUTC],
                  ["MeasurementTemperature",   $currentDataTemperature],
                  ["MeasurementPressure",      $currentDataPressure],
                  ["MeasurementFlowrate",      $currentDataFlowrate]
                )
                if( $hash->{helper}{LogFileEnabled} eq "1" ); # only if LogFile in use
              
              $lastProcessedTimestamp_LUTC = $currentMeasurementDataTimestamp_LUTC;
            }
            
            # shift next entry
            $currentMeasurement = shift(@measurementList);

            if(defined($currentMeasurement))
            {
              ($currentMeasurementDataTimestamp_LTZ_s, $currentMeasurementDataTimestamp_LUTC, $currentMeasurementData) = @{$currentMeasurement};
              
              Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - Measurement: $currentMeasurementDataTimestamp_LUTC");
            }
            else
            {
              Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - Measurement: finished");
            }
          }
          elsif(defined($currentWithdrawal))
          {
            # don't process measurevalues with timestamp before $lastProcessedTimestamp
            if($lastProcessedTimestamp_LUTC gt $currentWithdrawalDataTimestamp_LUTC)
            {
              Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) - old Measurement: $lastProcessedTimestamp_LUTC > $currentWithdrawalDataTimestamp_LUTC");
            }
            else
            {
              $currentWithdrawalTimestampStart_LUTC = $currentWithdrawalData->{starttime};
              $currentWithdrawalTimestampStop_LUTC  = $currentWithdrawalData->{stoptime};
              $currentWithdrawalDuration            = $currentWithdrawalData->{duration};
              $currentWithdrawalConsumption         = $currentWithdrawalData->{waterconsumption};
              $currentWithdrawalMaxFlowrate         = $currentWithdrawalData->{maxflowrate};
              $currentWithdrawalHotWaterShare       = $currentWithdrawalData->{hotwater_share};
              $currentWithdrawalCostWater           = $currentWithdrawalData->{water_cost};
              $currentWithdrawalCostEnergy          = $currentWithdrawalData->{energy_cost};

              # force the timestamp-seconds-string to have a well known length
              # fill with leading zeros
              my $currentWithdrawalTimestamp_LTZ_s_string = GroheOndusSmartDevice_GetLTZStringFromLUTC($currentWithdrawalTimestampStart_LUTC);

              $hash->{helper}{TotalAnalyzeStartTimestamp} = $currentWithdrawalDataTimestamp_LUTC if($hash->{helper}{TotalWithdrawalCount} == 0);
              $hash->{helper}{TotalAnalyzeEndTimestamp} = $currentWithdrawalDataTimestamp_LUTC;

              $hash->{helper}{TotalWaterConsumption} += $currentWithdrawalConsumption
                if(defined($currentWithdrawalConsumption));
              $hash->{helper}{TotalHotWaterShare} += $currentWithdrawalHotWaterShare
                if(defined($currentWithdrawalHotWaterShare));
              $hash->{helper}{TotalWaterCost} += $currentWithdrawalCostWater
                if(defined($currentWithdrawalCostWater));
              $hash->{helper}{TotalEnergyCost} += $currentWithdrawalCostEnergy
                if(defined($currentWithdrawalCostEnergy));
              $hash->{helper}{TotalWithdrawalCount}++;
              $totalValuesChanged = 1;

              if($lastProcessedWithdrawalTimestamp_LUTC lt $todayMidnight_LTZ and   # last is yesterday
                not ($currentWithdrawalDataTimestamp_LUTC lt $todayMidnight_LTZ))   # and current is today -> today begins
              {
                $hash->{helper}{TodayAnalyzeStartTimestamp} = $currentWithdrawalDataTimestamp_LUTC;
                $hash->{helper}{TodayAnalyzeEndTimestamp} = $currentWithdrawalDataTimestamp_LUTC;
                
                $hash->{helper}{TodayWaterConsumption} = $currentWithdrawalConsumption
                  if(defined($currentWithdrawalConsumption));
                $hash->{helper}{TodayHotWaterShare} = $currentWithdrawalHotWaterShare
                  if(defined($currentWithdrawalHotWaterShare));
                $hash->{helper}{TodayWaterCost} = $currentWithdrawalCostWater
                  if(defined($currentWithdrawalCostWater));
                $hash->{helper}{TodayEnergyCost} = $currentWithdrawalCostEnergy
                  if(defined($currentWithdrawalCostEnergy));
                $hash->{helper}{TodayMaxFlowrate} = $currentWithdrawalMaxFlowrate
                  if(defined($currentWithdrawalMaxFlowrate));
                $hash->{helper}{TodayWithdrawalCount} = 1;
                $todaysValuesChanged = 1;
              }
              elsif(not ($currentWithdrawalDataTimestamp_LUTC lt $todayMidnight_LTZ)) # within today
              {
                $hash->{helper}{TodayAnalyzeEndTimestamp} = $currentWithdrawalDataTimestamp_LUTC;
                $hash->{helper}{TodayWaterConsumption} += $currentWithdrawalConsumption
                  if(defined($currentWithdrawalConsumption));
                $hash->{helper}{TodayHotWaterShare} += $currentWithdrawalHotWaterShare
                  if(defined($currentWithdrawalHotWaterShare));
                $hash->{helper}{TodayWaterCost} += $currentWithdrawalCostWater
                  if(defined($currentWithdrawalCostWater));
                $hash->{helper}{TodayEnergyCost} += $currentWithdrawalCostEnergy
                  if(defined($currentWithdrawalCostEnergy));
                $hash->{helper}{TodayMaxFlowrate} = $currentWithdrawalMaxFlowrate
                  if(defined($currentWithdrawalMaxFlowrate));
                $hash->{helper}{TodayWithdrawalCount}++;
                $todaysValuesChanged = 1;
              }
              else
              {
                # not within today
              }
              $lastProcessedWithdrawalTimestamp_LUTC = $currentWithdrawalDataTimestamp_LUTC;

              if( $hash->{helper}{GetSuspendReadings} eq "0")
              {
                readingsBeginUpdate($hash);
  
                readingsBulkUpdateIfChanged( $hash, "MeasurementWithdrawalTimestampStart", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalTimestampStart_LUTC )
                  if( defined($currentWithdrawalTimestampStart_LUTC) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementWithdrawalTimestampStop", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalTimestampStop_LUTC )
                  if( defined($currentWithdrawalTimestampStop_LUTC) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementWithdrawalDuration", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalDuration )
                  if( defined($currentWithdrawalDuration) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementWaterConsumption", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalConsumption )
                  if( defined($currentWithdrawalConsumption) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementMaxFlowrate", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalMaxFlowrate )
                  if( defined($currentWithdrawalMaxFlowrate) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementHotWaterShare", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalHotWaterShare )
                  if( defined($currentWithdrawalHotWaterShare) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementWaterCost", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalCostWater )
                  if( defined($currentWithdrawalCostWater) );
                readingsBulkUpdateIfChanged( $hash, "MeasurementEnergyCost", $CurrentMeasurementFormatVersion . $currentWithdrawalTimestamp_LTZ_s_string . " " . $currentWithdrawalCostEnergy )
                  if( defined($currentWithdrawalCostEnergy) );
  
                readingsEndUpdate( $hash, 1 );
              }

              # if enabled write MeasureValues to own FileLog
              GroheOndusSmartDevice_FileLog_MeasureValueWrite($hash, "Withdrawal", $currentMeasurementDataTimestamp_LTZ_s, 
                  ["TimestampStart", $currentWithdrawalTimestampStart_LUTC],
                  ["TimestampStop",  $currentWithdrawalTimestampStop_LUTC],
                  ["Duration",       $currentWithdrawalDuration],
                  ["Consumption",    $currentWithdrawalConsumption],
                  ["MaxFlowrate",    $currentWithdrawalMaxFlowrate],
                  ["HotWaterShared", $currentWithdrawalHotWaterShare],
                  ["CostWater",      $currentWithdrawalCostWater],
                  ["CostEnergy",     $currentWithdrawalCostEnergy],
                )
                if( $hash->{helper}{LogFileEnabled} eq "1" ); # only if LogFile in use

              $lastProcessedTimestamp_LUTC = $currentWithdrawalDataTimestamp_LUTC;
            }

            # shift next entry
            $currentWithdrawal = shift(@withdrawalList);

            if(defined($currentWithdrawal))
            {
              ($currentWithdrawalDataTimestamp_LTZ_s, $currentWithdrawalDataTimestamp_LUTC, $currentWithdrawalData) = @{$currentWithdrawal};

              Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) -  Withdrawal: $currentWithdrawalDataTimestamp_LUTC");
            }
            else
            {
              Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData($name) -  Withdrawal: finished");
            }
          }
        }
        
        $hash->{helper}{LastProcessedTimestamp_LUTC}            = $lastProcessedTimestamp_LUTC;
        $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC}  = $lastProcessedWithdrawalTimestamp_LUTC;
        $hash->{helper}{Telegram_GetDataCounter}++;

        # save values in store
        GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "LastProcessedTimestamp_LUTC", $hash->{helper}{LastProcessedTimestamp_LUTC});
        GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "LastProcessedWithdrawalTimestamp_LUTC", $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC});
        
        # total values
        if($totalValuesChanged != 0)
        {
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalAnalyzeStartTimestamp", $hash->{helper}{TotalAnalyzeStartTimestamp});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalAnalyzeEndTimestamp", $hash->{helper}{TotalAnalyzeEndTimestamp});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalWithdrawalCount", $hash->{helper}{TotalWithdrawalCount});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalWaterConsumption", $hash->{helper}{TotalWaterConsumption});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalHotWaterShare", $hash->{helper}{TotalHotWaterShare});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalWaterCost", $hash->{helper}{TotalWaterCost});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TotalEnergyCost", $hash->{helper}{TotalEnergyCost});
        }

        # today values
        if($todaysValuesChanged != 0)
        {
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayAnalyzeStartTimestamp", $hash->{helper}{TodayAnalyzeStartTimestamp});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayAnalyzeEndTimestamp", $hash->{helper}{TodayAnalyzeEndTimestamp});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayWithdrawalCount", $hash->{helper}{TodayWithdrawalCount});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayWaterConsumption", $hash->{helper}{TodayWaterConsumption});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayHotWaterShare", $hash->{helper}{TodayHotWaterShare});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayWaterCost", $hash->{helper}{TodayWaterCost});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayEnergyCost", $hash->{helper}{TodayEnergyCost});
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "TodayMaxFlowrate", $hash->{helper}{TodayMaxFlowrate});
        }
      }
      # {
      #   "code":404,
      #   "message":"Not found"
      # }
      elsif( defined( $decode_json ) and
        defined( $decode_json->{code} ) and
        defined( $decode_json->{message} ) )
      {
        my $errorCode = $decode_json->{code};
        my $errorMessage = $decode_json->{message};
        my $message = "TimeStamp: " . strftime($TimeStampFormat, localtime(gettimeofday())) . " Code: " . $errorCode . " Message: " . $decode_json->{message}; 

        # Not found -> no data in requested timespan
        if( $errorCode == 404 )
        {
          Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - $message");
          readingsSingleUpdate( $hash, "Message", $message, 1 );
        }
        # Too many requests 
        elsif($errorCode == 429)
        {
          Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - $message");
          readingsSingleUpdate( $hash, "Message", $message, 1 );
        }
        else
        {
          Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetData($name) - $message");
          readingsSingleUpdate( $hash, "Message", $message, 1 );
        }
      }
      else
      {
        $errorMsg = "UNKNOWN Data";
      }
    }

    $hash->{helper}{Telegram_GetDataTimeProcess}  = gettimeofday() - $stopwatch;

    if($errorMsg eq "")
    {
      my $applianceTDT_UTC = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{ApplianceTDT_LUTC});

      # requested timespan contains TDT so break historic get
      if($callbackparam->{requestToTimestamp_UTC} gt $applianceTDT_UTC)
      {
        readingsBeginUpdate($hash);

        if($hash->{helper}{GetInProgress} ne "0" and 
          $hash->{helper}{GetSuspendReadings} ne "0")
        {
          readingsBulkUpdateIfChanged($hash, "state", "getting historic data finished", 1);
        }

        $hash->{helper}{GetSuspendReadings} = "0";
        GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});
        
        $hash->{helper}{GetInProgress} = "0";
        GroheOndusSmartDevice_UpdateInternals($hash);

        readingsBulkUpdateIfChanged( $hash, "LastDataTimestamp", $currentDataTimestamp_LUTC )
          if(defined($currentDataTimestamp_LUTC));
        readingsBulkUpdateIfChanged( $hash, "LastFlowrate", $currentDataFlowrate )
          if(defined($currentDataFlowrate));
        readingsBulkUpdateIfChanged( $hash, "LastTemperature", $currentDataTemperature )
          if(defined($currentDataTemperature));
        readingsBulkUpdateIfChanged( $hash, "LastPressure", $currentDataPressure )
          if(defined($currentDataPressure));

        readingsBulkUpdateIfChanged( $hash, "LastWithdrawalTimestampStart", $currentWithdrawalTimestampStart_LUTC )
          if(defined($currentWithdrawalTimestampStart_LUTC));
        readingsBulkUpdateIfChanged( $hash, "LastWithdrawalTimestampStop", $currentWithdrawalTimestampStop_LUTC )
          if(defined($currentWithdrawalTimestampStop_LUTC));
        readingsBulkUpdateIfChanged( $hash, "LastWithdrawalDuration", $currentWithdrawalDuration )
          if(defined($currentWithdrawalDuration));
        readingsBulkUpdateIfChanged( $hash, "LastWaterConsumption", $currentWithdrawalConsumption )
          if(defined($currentWithdrawalConsumption));
        readingsBulkUpdateIfChanged( $hash, "LastEnergyCost", $currentWithdrawalCostEnergy )
          if(defined($currentWithdrawalCostEnergy));
        readingsBulkUpdateIfChanged( $hash, "LastWaterCost", $currentWithdrawalCostWater )
          if(defined($currentWithdrawalCostWater));
        readingsBulkUpdateIfChanged( $hash, "LastHotWaterShare", $currentWithdrawalHotWaterShare )
          if(defined($currentWithdrawalHotWaterShare));
        readingsBulkUpdateIfChanged( $hash, "LastMaxFlowrate", $currentWithdrawalMaxFlowrate )
          if(defined($currentWithdrawalMaxFlowrate));

        readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeStartTimestamp", $hash->{helper}{TodayAnalyzeStartTimestamp} )
          if(defined($hash->{helper}{TodayAnalyzeStartTimestamp}));
        readingsBulkUpdateIfChanged( $hash, "TodayAnalyzeEndTimestamp", $hash->{helper}{TodayAnalyzeEndTimestamp} )
          if(defined($hash->{helper}{TodayAnalyzeEndTimestamp}));
        readingsBulkUpdateIfChanged( $hash, "TodayWaterConsumption", $hash->{helper}{TodayWaterConsumption} )
          if(defined($hash->{helper}{TodayWaterConsumption}));
        readingsBulkUpdateIfChanged( $hash, "TodayWithdrawalCount", $hash->{helper}{TodayWithdrawalCount} )
          if(defined($hash->{helper}{TodayWithdrawalCount}));
        readingsBulkUpdateIfChanged( $hash, "TodayEnergyCost", $hash->{helper}{TodayEnergyCost} )
          if(defined($hash->{helper}{TodayEnergyCost}));
        readingsBulkUpdateIfChanged( $hash, "TodayWaterCost", $hash->{helper}{TodayWaterCost} )
          if(defined($hash->{helper}{TodayWaterCost}));
        readingsBulkUpdateIfChanged( $hash, "TodayHotWaterShare", $hash->{helper}{TodayHotWaterShare} )
          if(defined($hash->{helper}{TodayHotWaterShare}));
        readingsBulkUpdateIfChanged( $hash, "TodayMaxFlowrate", $hash->{helper}{TodayMaxFlowrate} )
          if(defined($hash->{helper}{TodayMaxFlowrate}));

        readingsBulkUpdateIfChanged( $hash, "TotalAnalyzeStartTimestamp", $hash->{helper}{TotalAnalyzeStartTimestamp} )
          if(defined($hash->{helper}{TotalAnalyzeStartTimestamp}));
        readingsBulkUpdateIfChanged( $hash, "TotalAnalyzeEndTimestamp", $hash->{helper}{TotalAnalyzeEndTimestamp} )
          if(defined($hash->{helper}{TotalAnalyzeEndTimestamp}));
        readingsBulkUpdateIfChanged( $hash, "TotalWaterConsumption", $hash->{helper}{TotalWaterConsumption} )
          if(defined($hash->{helper}{TotalWaterConsumption}));
        readingsBulkUpdateIfChanged( $hash, "TotalWithdrawalCount", $hash->{helper}{TotalWithdrawalCount} )
          if(defined($hash->{helper}{TotalWithdrawalCount}));
        readingsBulkUpdateIfChanged( $hash, "TotalEnergyCost", $hash->{helper}{TotalEnergyCost} )
          if(defined($hash->{helper}{TotalEnergyCost}));
        readingsBulkUpdateIfChanged( $hash, "TotalWaterCost", $hash->{helper}{TotalWaterCost} )
          if(defined($hash->{helper}{TotalWaterCost}));
        readingsBulkUpdateIfChanged( $hash, "TotalHotWaterShare", $hash->{helper}{TotalHotWaterShare} )
          if(defined($hash->{helper}{TotalHotWaterShare}));

        readingsEndUpdate( $hash, 1 );

        # if there is a callback then call it
        if( defined($callbackSuccess) )
        {
          Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackSuccess");
          $callbackSuccess->();
        }
      }
      else
      {
        # historic get still active
        $hash->{helper}{GetInProgress} = "1";
        GroheOndusSmartDevice_UpdateInternals($hash);

        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged( $hash, "state", "getting historic data $callbackparam->{requestToTimestamp_UTC}", 1 );
        readingsEndUpdate( $hash, 1 );

        # reload timer
        my $nextTimer = gettimeofday() + $GetLoopDataInterval;
        InternalTimer( $nextTimer, "GroheOndusSmartDevice_SenseGuard_GetData_TimerExecute", 
          [$hash, 
          $callbackparam->{requestToTimestamp_UTC}, 
          $callbackparam->{GetCampain}, 
          $callbackSuccess, 
          $callbackFail]
        );
      }
    }
    else
    {
      # error -> historic get failed
      $hash->{helper}{GetInProgress} = "0";
      GroheOndusSmartDevice_UpdateInternals($hash);

      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  # if there is a timer remove it
  GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($hash);

  my $deviceId          = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if(defined($device_locationId) and
    defined($device_roomId))
  {
    my $lastTDT_LUTC      = $hash->{helper}{ApplianceTDT_LUTC_GetData};
    my $applianceTDT_LUTC = $hash->{helper}{ApplianceTDT_LUTC};
    
    if($hash->{helper}{GetInProgress} ne "1" and              # only check if no campain is running:
      $hash->{helper}{LastProcessedTimestamp_LUTC} ne "" and  # if there is a LastProcessedTimestamp
      $hash->{helper}{OverrideCheckTDT} eq "0" and            # if check is disabled 
      $lastTDT_LUTC eq $applianceTDT_LUTC)                    # if TDT is processed
    {                                                         # -> don't get new data
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - no new TDT");

      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      # add offset in seconds to get to-timestamp
      my $requestToTimestamp_UTC_s = time_str2num($requestFromTimestamp_UTC) + $hash->{helper}{GetTimespan};
      my @t = localtime($requestToTimestamp_UTC_s);
      my $requestToTimestamp_UTC = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
      
      my $param = {};
      $param->{method}                          = "GET";
      $param->{url}                             = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/data?from=" . $requestFromTimestamp_UTC . "&to=" . $requestToTimestamp_UTC;
      $param->{header}                          = "Content-Type: application/json";
      $param->{data}                            = "{}";
      $param->{httpversion}                     = "1.0";
      $param->{ignoreredirects}                 = 0;
      $param->{keepalive}                       = 1;
      $param->{timeout}                         = 10;
      $param->{incrementalTimeout}              = 1;

      $param->{resultCallback}                  = $resultCallback;
      $param->{requestFromTimestamp_UTC}        = $requestFromTimestamp_UTC;
      $param->{requestToTimestamp_UTC}          = $requestToTimestamp_UTC;
      $param->{GetCampain}                      = $hash->{helper}{GetCampain};
      $param->{ApplianceTDT_LUTC_GetData}       = $applianceTDT_LUTC;
      $param->{timestampStart}                  = gettimeofday();

      $hash->{helper}{GetInProgress}            = "1";
      $hash->{helper}{Telegram_GetDataIOWrite}  = strftime($TimeStampFormat, localtime($param->{timestampStart}));
      GroheOndusSmartDevice_UpdateInternals($hash);

      GroheOndusSmartDevice_IOWrite( $hash, $param );
    }
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetData_Last( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetData_Last($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  if($hash->{helper}{GetInProgress} eq "1")
  {
    Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData_Last($name) - GetInProgress");
  }
  else
  {
    my $requestFromTimestamp_UTC      = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{LastProcessedTimestamp_LUTC});
    my $applianceTDT_UTC              = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{ApplianceTDT_LUTC});
    my $getHistoricDataStartDate_UTC  = GroheOndusSmartDevice_GetUTCFromLTZ($hash->{helper}{LogFileGetDataStartDate_LTZ});

    if(not defined($requestFromTimestamp_UTC))
    {
      $requestFromTimestamp_UTC = GroheOndusSmartDevice_GetUTCMidnightDate(0);
    }
    elsif(defined($getHistoricDataStartDate_UTC) and
      $getHistoricDataStartDate_UTC gt $requestFromTimestamp_UTC)
    {
      $requestFromTimestamp_UTC = $getHistoricDataStartDate_UTC;
    }

    if($requestFromTimestamp_UTC lt $applianceTDT_UTC)
    {
      Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData_Last($name) - requestFromTimestamp_UTC: $requestFromTimestamp_UTC");
    
      $hash->{helper}{GetCampain}++;                                  # new campain-counter to stop current running old campains

      GroheOndusSmartDevice_SenseGuard_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);
    }
    else
    {
      Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData_Last($name) - requestFromTimestamp_UTC: $requestFromTimestamp_UTC > applianceTDT: $applianceTDT_UTC");
    }
  }
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetData_Stop( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetData_Stop($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};

  if($hash->{helper}{GetInProgress} eq "1")
  {
    Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData_Stop($name)");
    
    GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($hash);

    $hash->{helper}{GetInProgress}                = "0";
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    $hash->{helper}{GetSuspendReadings}           = "0"; # suspend readings
    $hash->{helper}{GetCampain}++;                       # new campain-counter to stop current running old campains
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData_StartCampain", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

    GroheOndusSmartDevice_UpdateInternals($hash);

    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged($hash, "state", "getting historic data stopped", 1);
    readingsEndUpdate( $hash, 1 );
  }
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetData_StartCampain( $hash, $requestFromTimestamp, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetData_StartCampain($$;$$)
{
  my ($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail) = @_;
  my $name = $hash->{NAME};

  $hash->{helper}{TotalAnalyzeStartTimestamp}             = "";
  $hash->{helper}{TotalAnalyzeEndTimestamp}               = "";
  $hash->{helper}{TotalWithdrawalCount}                   = 0;
  $hash->{helper}{TotalWaterConsumption}                  = 0;
  $hash->{helper}{TotalHotWaterShare}                     = 0;
  $hash->{helper}{TotalWaterCost}                         = 0;
  $hash->{helper}{TotalEnergyCost}                        = 0;

  $hash->{helper}{TodayAnalyzeStartTimestamp}             = "";
  $hash->{helper}{TodayAnalyzeEndTimestamp}               = "";
  $hash->{helper}{TodayWithdrawalCount}                   = 0;
  $hash->{helper}{TodayWaterConsumption}                  = 0;
  $hash->{helper}{TodayHotWaterShare}                     = 0;
  $hash->{helper}{TodayWaterCost}                         = 0;
  $hash->{helper}{TodayEnergyCost}                        = 0;
  $hash->{helper}{TodayMaxFlowrate}                       = 0;

  $hash->{helper}{LogFileName}                            = "";   # reset internal to delete existing file
  $hash->{helper}{LastProcessedTimestamp_LUTC}            = "";   # reset internal to restart processing
  $hash->{helper}{LastProcessedWithdrawalTimestamp_LUTC}  = "";   # reset internal to restart processing
  $hash->{helper}{GetCampain}++;                                  # new campain-counter to stop current running old campains

  $hash->{helper}{GetSuspendReadings}                     = "1";  # suspend readings
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_SenseGuard_GetData_StartCampain", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

  GroheOndusSmartDevice_SenseGuard_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetData_TimerExecute( @args )
sub GroheOndusSmartDevice_SenseGuard_GetData_TimerExecute($)
{
  my ( $args ) = @_;
  my ( $hash, $requestFromTimestamp_UTC, $getCampain, $callbackSuccess, $callbackFail ) = @{$args};
  my $name = $hash->{NAME};

  if($getCampain != $hash->{helper}{GetCampain})
  {
    Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData_TimerExecute($name) - dropping old Campain");

    # if there is a callback then call it
    if(defined($callbackFail))
    {
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetData($name) - callbackFail");
      $callbackFail->();
    }
  }
  else
  {
    GroheOndusSmartDevice_SenseGuard_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);  
  }
}

##################################
# GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove( @args )
sub GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};
  
  my $functionName = "GroheOndusSmartDevice_SenseGuard_GetData_TimerExecute"; 
  Log3($name, 5, "GroheOndusSmartDevice_SenseGuard_GetData_TimerRemove($name) - $functionName");
  
  RemoveInternalTimer($hash, $functionName);
}

#################################
# GroheOndusSmartDevice_SenseGuard_GetApplianceCommand( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetCommandTimeRequest}  = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetCommandCallback}     = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "Appliance_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "Appliance_JSON_ERROR", $@, 1 );
        }
        $errorMsg = "GETAPPLIANCECommand_JSON_ERROR";
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
        if(defined( $decode_json->{command} ) and 
          ref( $decode_json->{command} ) eq "HASH" )
        {
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

          $hash->{helper}{Telegram_GetCommandCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetCommandTimeProcess}  = gettimeofday() - $stopwatch;

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/command";
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_GetCommandIOWrite}  = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($name) - callbackFail");
      $callbackFail->();
    }
  }
}

#####################################
# GroheOndusSmartDevice_SenseGuard_Set( $hash, $name, $cmd, @args )
sub GroheOndusSmartDevice_SenseGuard_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_Set($name) - cmd= $cmd");

  ### Command "update"
  if( lc $cmd eq lc "update" )
  {
    GroheOndusSmartDevice_SenseGuard_Update($hash);
    return;
  }
  ### Command "on"
  elsif( lc $cmd eq lc "on" )
  {
    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "valve_open", "on");
    return;
  }
  ### Command "off"
  elsif( lc $cmd eq lc "off" )
  {
    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "valve_open", "off");
    return;
  }
  ### Command "buzzer"
  elsif( lc $cmd eq lc "buzzer" )
  {
    # parameter is "on" or "off" so convert to "true" : "false"
    my $onoff = lc join( " ", @args ) eq lc "on" ? "true" : "false";

    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "buzzer_on", $onoff);
    return;
  }
  ### Command "valve"
  elsif( lc $cmd eq lc "valve" )
  {
    # parameter is "on" or "off" so convert to "true" : "false"
    my $onoff = lc join( " ", @args ) eq lc "on" ? "true" : "false";

    GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($hash, "valve_open", $onoff);
    return;
  }
  ### Command "TotalWaterConsumption"
  elsif( lc $cmd eq lc "TotalWaterConsumption" )
  {
    my $totalWaterConsumption = undef;
    
    $totalWaterConsumption = GroheOndusSmartDevice_Getnum($args[0])
      if( @args == 1 );
    
    return "usage: $cmd [<devicename>] 123.4"
      if(not defined($totalWaterConsumption));
    
    my $currentTotalWaterConsumption = ReadingsVal($name, "TotalWaterConsumption", 0);
    my $offsetTotalWaterConsumption = AttrVal($name, "offsetTotalWaterConsumption", 0);
    my $delta = $totalWaterConsumption - $currentTotalWaterConsumption - $offsetTotalWaterConsumption;

    CommandAttr( undef, "$name offsetTotalWaterConsumption $delta" );
    readingsSingleUpdate( $hash, "TotalWaterConsumption", $totalWaterConsumption, 1 );
    
    return;
  }
  ### Command "TotalWaterCost"
  elsif( lc $cmd eq lc "TotalWaterCost" )
  {
    my $totalWaterCost = undef;
    
    $totalWaterCost = GroheOndusSmartDevice_Getnum($args[0])
      if( @args == 1 );
    
    return "usage: $cmd [<devicename>] 123.4"
      if(not defined($totalWaterCost));

    my $currentTotalWaterCost = ReadingsVal($name, "TotalWaterCost", 0);
    my $offsetTotalWaterCost = AttrVal($name, "offsetTotalWaterCost", 0);
    my $delta = $totalWaterCost - $currentTotalWaterCost - $offsetTotalWaterCost;

    CommandAttr( undef, "$name offsetTotalWaterCost $delta" );
    readingsSingleUpdate( $hash, "TotalWaterCost", $totalWaterCost, 1 );

    return;
  }
  ### Command "TotalEnergyCost"
  elsif( lc $cmd eq lc "TotalEnergyCost" )
  {
    my $totalEnergyCost = undef;
    
    $totalEnergyCost = GroheOndusSmartDevice_Getnum($args[0])
      if( @args == 1 );
    
    return "usage: $cmd [<devicename>] 123.4"
      if(not defined($totalEnergyCost));

    my $currentTotalEnergyCost = ReadingsVal($name, "TotalEnergyCost", 0);
    my $offsetTotalEnergyCost = AttrVal($name, "offsetTotalEnergyCost", 0);
    my $delta = $totalEnergyCost - $currentTotalEnergyCost - $offsetTotalEnergyCost;

    CommandAttr( undef, "$name offsetTotalEnergyCost $delta" );
    readingsSingleUpdate( $hash, "TotalEnergyCost", $totalEnergyCost, 1 );

    return;
  }
  ### Command "TotalHotWaterShare"
  elsif( lc $cmd eq lc "TotalHotWaterShare" )
  {
    my $totalHotWaterShare = undef;
    
    $totalHotWaterShare = GroheOndusSmartDevice_Getnum($args[0])
      if( @args == 1 );
    
    return "usage: $cmd [<devicename>] 123.4"
      if(not defined($totalHotWaterShare));

    my $currentTotalHotWaterShare = ReadingsVal($name, "TotalHotWaterShare", 0);
    my $offsetTotalHotWaterShare = AttrVal($name, "offsetTotalHotWaterShare", 0);
    my $delta = $totalHotWaterShare - $currentTotalHotWaterShare - $offsetTotalHotWaterShare;

    CommandAttr( undef, "$name offsetTotalEnergyCost $delta" );
    readingsSingleUpdate( $hash, "TotalHotWaterShare", $totalHotWaterShare, 1 );

    return;
  }
  ### Command "clearreadings"
  elsif( lc $cmd eq lc "clearreadings" )
  {
    fhem("deletereading $name .*", 1);
    return;
  }
  ### Command "logFileDelete"
  elsif( lc $cmd eq lc "logFileDelete" )
  {
    my $logFileName = $hash->{helper}{LogFileName};
    GroheOndusSmartDevice_FileLog_Delete($hash, $logFileName);
    return;
  }
  ### Command "logFileGetHistoricData"
  elsif( lc $cmd eq lc "logFileGetHistoricData" )
  {
    my $value = "";
    my $requestFromTimestamp_UTC = "";

    $value = $args[0]
      if(@args == 1);

    if(lc $value eq lc "stop")
    {
      GroheOndusSmartDevice_SenseGuard_GetData_Stop($hash);
    }
    else
    {
      my $getHistoricDataStartDate_UTC = GroheOndusSmartDevice_GetUTCFromLTZ($hash->{helper}{LogFileGetDataStartDate_LTZ});
      my $applianceInstallationDate_UTC = GroheOndusSmartDevice_GetUTCFromLUTC(ReadingsVal($name, "ApplianceInstallationDate", undef));
      
      if($value eq "")
      {
        if(defined($getHistoricDataStartDate_UTC))
        {
          $requestFromTimestamp_UTC = $getHistoricDataStartDate_UTC;
        }
        elsif(defined($applianceInstallationDate_UTC))
        {
          $requestFromTimestamp_UTC = $applianceInstallationDate_UTC;
        }
      }
      else
      {
        # try to parse $value to timestamp
        my $timestampLocal_s = str2time($value);
        
        if(not defined($timestampLocal_s))
        {
          return "illegal format";
        }
        
        my @t = localtime($timestampLocal_s);
        $requestFromTimestamp_UTC = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);

        # limit to applianceInstallationDate
        if(defined($applianceInstallationDate_UTC) and
          $requestFromTimestamp_UTC lt $applianceInstallationDate_UTC)
        {
          $requestFromTimestamp_UTC = $applianceInstallationDate_UTC;
        }
      }

      if(defined($requestFromTimestamp_UTC) and
        $requestFromTimestamp_UTC ne "")
      {
        GroheOndusSmartDevice_SenseGuard_GetData_StartCampain($hash, $requestFromTimestamp_UTC);
      }
    }

    return;
  }
  ### Command "logFileCreateFileLogDevice"
  elsif( lc $cmd eq lc "logFileCreateFileLogDevice" )
  {
    return "usage: $cmd [<devicename>]"
      if( @args > 1 );
    
    my $logFileName = ($args[0] =~ tr/ //ds)         # trim whitespaces
      if( @args == 1 );
    
    GroheOndusSmartDevice_FileLog_Create_FileLogDevice($hash, $logFileName);
    
    return;
  }
  ### Command "debugRefreshValues"
  elsif( lc $cmd eq lc "debugRefreshValues" )
  {
    GroheOndusSmartDevice_SenseGuard_GetData_Last($hash);
    return;
  }
  ### Command "debugRefreshState"
  elsif( lc $cmd eq lc "debugRefreshState" )
  {
    GroheOndusSmartDevice_SenseGuard_GetState($hash);
    return;
  }
  ### Command "debugRefreshConfig"
  elsif( lc $cmd eq lc "debugRefreshConfig" )
  {
    GroheOndusSmartDevice_SenseGuard_GetConfig($hash);
    return;
  }
  ### Command "debugGetApplianceCommand"
  elsif( lc $cmd eq lc "debugGetApplianceCommand" )
  {
    GroheOndusSmartDevice_SenseGuard_GetApplianceCommand($hash);
    return;
  }
  ### Command "debugOverrideCheckTDT"
  elsif( lc $cmd eq lc "debugOverrideCheckTDT" )
  {
    $hash->{helper}{OverrideCheckTDT} = join( " ", @args );
    GroheOndusSmartDevice_UpdateInternals($hash);
    return;
  }
  ### unknown Command
  else
  {
    my $list = "";
    $list .= "update:noArg ";
#    $list .= "on:noArg ";
#    $list .= "off:noArg ";
    $list .= "buzzer:on,off ";
    $list .= "valve:on,off ";

    $list .= "TotalWaterConsumption ";
    $list .= "TotalWaterCost ";
    $list .= "TotalEnergyCost ";
    $list .= "TotalHotWaterShare ";

    $list .= "clearreadings:noArg ";
    
    $list .= "logFileDelete:noArg "
      if($hash->{helper}{LogFileEnabled} ne "0" and  # check if in logfile mode
      defined($hash->{helper}{LogFileName}) and      # check if filename is defined
      -e $hash->{helper}{LogFileName});              # check if file exists

    my $logFileGetHistoricDataArgs = "";
    if($hash->{helper}{GetSuspendReadings} ne "0")
    {
      $logFileGetHistoricDataArgs = "stop";
    }
    $list .= "logFileGetHistoricData:$logFileGetHistoricDataArgs "
      if($hash->{helper}{LogFileEnabled} ne "0");     # check if in logfile mode

    $list .= "logFileCreateFileLogDevice "
      if($hash->{helper}{LogFileEnabled} ne "0");     # check if in logfile mode

    $list .= "debugRefreshConfig:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugRefreshValues:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugRefreshState:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugGetApplianceCommand:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugOverrideCheckTDT:0,1 "
      if($hash->{helper}{DEBUG} ne "0");

    return "Unknown argument $cmd, choose one of $list";
  }
}

#################################
# GroheOndusSmartDevice_SenseGuard_SetApplianceCommand( $hash, $command, $setValue, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($$$;$$)
{
  my ( $hash, $command, $setValue, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_SetCommandTimeRequest}  = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_SetCommandCallback}     = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "ApplianceSet_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - JSON error while request: $@");

        if( AttrVal( $name, "ApplianceSet_debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "JSON_ERROR", $@, 1 );
        }
        $errorMsg = "SETAPPLIANCECommand_JSON_ERROR";
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
        if(defined( $decode_json->{command} ) and 
          ref( $decode_json->{command} ) eq "HASH" )
        {
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

          $hash->{helper}{Telegram_SetCommandCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_SetCommandTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId          = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};
  my $modelId           = 103;

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
      "appliance_id" => $deviceId,
      "type"         => $modelId,
      "command"      => 
      {
        # "measure_now" = 
        # "buzzer_on" =>
        # "buzzer_sound_profile" => 
        $command => lc $setValueString
        # "temp_user_unlock_on" =>
      }
    };

    my $param = {};
    $param->{method} = "POST";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/command";
    $param->{header} = "Content-Type: application/json";
    $param->{data} = encode_json($commandData);
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_SetCommandIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_SenseGuard_SetApplianceCommand($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_Sense_Update( $hash )
sub GroheOndusSmartDevice_Sense_Update($)
{
  my ( $hash ) = @_;
  my $name     = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartDevice_Sense_Update($name)");

  # parallel call:
  #GroheOndusSmartDevice_Sense_GetData($hash);
  #GroheOndusSmartDevice_Sense_GetState($hash);
  #GroheOndusSmartDevice_Sense_GetConfig($hash);
  
  # serial call:
  my $getData   = sub { GroheOndusSmartDevice_Sense_GetData_Last($hash); };
  my $getState  = sub { GroheOndusSmartDevice_Sense_GetState($hash, $getData); };
  my $getConfig = sub { GroheOndusSmartDevice_Sense_GetConfig($hash, $getState); };
  
  $getConfig->();
}

##################################
# GroheOndusSmartDevice_Sense_GetState( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Sense_GetState($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name     = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetStateTimeRequest} = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetStateCallback}    = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - resultCallback");

    if( $errorMsg eq "")
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "State_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Sense_GetState($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "State_JSON_ERROR", $@, 1 );
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
        if( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          foreach my $currentData ( @{ $decode_json } )
          {
            if( $currentData->{type} eq "update_available"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateUpdateAvailable", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "battery"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateBattery", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "connection"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateConnection", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "wifi_quality"
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

          $hash->{helper}{Telegram_GetStateCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetStateTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if($errorMsg eq "")
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/status";
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;

    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();

    $hash->{helper}{Telegram_GetStateIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Sense_GetState($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_Sense_GetConfig( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Sense_GetConfig($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetConfigTimeRequest} = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetConfigCallback}    = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "Config_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Sense_GetConfig($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "Config_JSON_ERROR", $@, 1 );
        }
        $errorMsg = "GETConfig_JSON_ERROR";
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
      
        if( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
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

          if( defined( $currentEntry )
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

            $hash->{helper}{ApplianceTDT_LUTC} = "$currentEntry->{tdt}"
              if( defined( $currentEntry->{tdt} ) );

            my $currentConfig = $currentEntry->{config};

            if( defined( $currentConfig )
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

              if( defined( $currentThresholds ) and
                ref( $currentThresholds ) eq "ARRAY" )
              {
                foreach my $currentThreshold ( @{ $currentThresholds} )
                {
                  if( "$currentThreshold->{quantity}" eq "temperature" )
                  {
                    if( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigTemperatureThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  } 
                  elsif( "$currentThreshold->{quantity}" eq "humidity" )
                  {
                    if( "$currentThreshold->{type}" eq "max" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigHumidityThresholdMax", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    } 
                    elsif( "$currentThreshold->{type}" eq "min" )
                    {
                      readingsBulkUpdateIfChanged( $hash, "ConfigHumidityThresholdMin", $currentThreshold->{enabled} ? $currentThreshold->{value} : "off" );
                      next;
                    }
                  }
                }
              }
            }
          }

          $hash->{helper}{Telegram_GetConfigCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetConfigTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_GetConfigIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Sense_GetConfig($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_Sense_GetData( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Sense_GetData($$;$$)
{
  my ( $hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail ) = @_;
  my $name     = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetDataTimeRequest}  = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetDataCallback}     = strftime($TimeStampFormat, localtime($stopwatch));
    $hash->{helper}{Telegram_GetDataCampain}      = $callbackparam->{GetCampain};
    Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - resultCallback");

    my $lastProcessedTimestamp_LUTC = $hash->{helper}{LastProcessedTimestamp_LUTC};
    
    my $currentDataTimestamp_LUTC   = undef;
    my $currentDataHumidity         = undef;
    my $currentDataTemperature      = undef;

    if($callbackparam->{GetCampain} != $hash->{helper}{GetCampain})
    {
      $errorMsg = "GetData old Campain";
    }
    elsif( $errorMsg eq "" )
    {
      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBeginUpdate($hash);
        readingsBulkUpdate( $hash, "Data_RAW", "\"" . $data . "\"", 1 );
        readingsEndUpdate( $hash, 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Sense_GetData($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBeginUpdate($hash);
          readingsBulkUpdate( $hash, "Data_JSON_ERROR", $@, 1 );
          readingsEndUpdate( $hash, 1 );
        }
        $errorMsg = "GetHistoricData_JSON_ERROR";
      }
      else
      {
        $hash->{helper}{ApplianceTDT_LUTC_GetData} = $callbackparam->{ApplianceTDT_LUTC_GetData};

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
        if( defined( $decode_json ) and
          defined( $decode_json->{data}->{measurement} ) and
          ref( $decode_json->{data}->{measurement} ) eq "ARRAY" )
        {
          # get entry with latest timestamp
          my $dataTimestamp = undef;
          my $loopCounter = 0;

          foreach my $currentData ( @{ $decode_json->{data}->{measurement} } )
          {
            # is this the correct dataset?
            if( defined( $currentData->{timestamp} ) and 
              defined( $currentData->{humidity} ) and 
              defined( $currentData->{temperature} ) )
            {
              $currentDataTimestamp_LUTC = $currentData->{timestamp};
              $currentDataHumidity       = $currentData->{humidity};
              $currentDataTemperature    = $currentData->{temperature};
              
              # don't process measurevalues with timestamp before $lastProcessedTimestamp
              if($currentDataTimestamp_LUTC gt $lastProcessedTimestamp_LUTC)
              {
                # force the timestamp-seconds-string to have a well known length
                # fill with leading zeros
                my $currentDataTimestamp_LTZ = GroheOndusSmartDevice_GetLTZFromLUTC($currentDataTimestamp_LUTC);
                my $currentDataTimestamp_LTZ_s = time_str2num($currentDataTimestamp_LTZ);
                my $currentDataTimestamp_LTZ_s_string = GroheOndusSmartDevice_GetLTZStringFromLUTC($currentDataTimestamp_LUTC);

                if( $hash->{helper}{GetSuspendReadings} eq "0")
                {
                  readingsBeginUpdate($hash);
    
                  readingsBulkUpdateIfChanged( $hash, "MeasurementDataTimestamp", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataTimestamp_LUTC )
                    if( defined($currentDataTimestamp_LUTC) );
                  readingsBulkUpdateIfChanged( $hash, "MeasurementHumidity", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataHumidity )
                    if( defined($currentDataHumidity) );
                  readingsBulkUpdateIfChanged( $hash, "MeasurementTemperature", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataTemperature )
                    if( defined($currentDataTemperature) );
    
                  readingsEndUpdate( $hash, 1 );
                }

                # if enabled write MeasureValues to own FileLog
                GroheOndusSmartDevice_FileLog_MeasureValueWrite($hash, "Measurement", $currentDataTimestamp_LTZ_s, 
                  ["MeasurementDataTimestamp",  $currentDataTimestamp_LUTC],
                  ["MeasurementHumidity",       $currentDataHumidity],
                  ["MeasurementTemperature",    $currentDataTemperature])
                  if( $hash->{helper}{LogFileEnabled} eq "1" ); # only if LogFile in use
                
                $lastProcessedTimestamp_LUTC = $currentDataTimestamp_LUTC;
              }
            }
            $loopCounter++;
          }

          $hash->{helper}{LastProcessedTimestamp_LUTC}      = $lastProcessedTimestamp_LUTC;
          $hash->{helper}{Telegram_GetDataLoopMeasurement}  = $loopCounter;
          $hash->{helper}{Telegram_GetDataCounter}++;

          # save values in store
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Sense_GetData", "LastProcessedTimestamp_LUTC", $hash->{helper}{LastProcessedTimestamp_LUTC});
        }
        # {
        #   "code":404,
        #   "message":"Not found"
        # }
        elsif( defined( $decode_json ) and
          defined( $decode_json->{code} ) and
          defined( $decode_json->{message} ) )
        {
          my $errorCode = $decode_json->{code};
          my $errorMessage = $decode_json->{message};
          my $message = "TimeStamp: " . strftime($TimeStampFormat, localtime(gettimeofday())) . " Code: " . $errorCode . " Message: " . $decode_json->{message}; 

          # Not found -> no data in requested timespan
          if( $errorCode == 404 )
          {
            Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - $message");
            readingsSingleUpdate( $hash, "Message", $message, 1 );
          }
          # Too many requests 
          elsif($errorCode == 429)
          {
            Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - $message");
            readingsSingleUpdate( $hash, "Message", $message, 1 );
          }
          else
          {
            Log3($name, 3, "GroheOndusSmartDevice_Sense_GetData($name) - $message");
            readingsSingleUpdate( $hash, "Message", $message, 1 );
          }
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
      }
    }

    $hash->{helper}{Telegram_GetDataTimeProcess}  = gettimeofday() - $stopwatch;

    if($errorMsg eq "")
    {
      my $applianceTDT_UTC = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}->{ApplianceTDT_LUTC});

      # requested timespan contains TDT so break historic get
      if($callbackparam->{requestToTimestamp_UTC} gt $applianceTDT_UTC)
      {
        readingsBeginUpdate($hash);

        if($hash->{helper}{GetInProgress} ne "0" and 
          $hash->{helper}{GetSuspendReadings} ne "0")
        {
          readingsBulkUpdateIfChanged($hash, "state", "getting historic data finished", 1);
        }

        $hash->{helper}{GetSuspendReadings} = "0";
        GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Sense_GetData", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

        $hash->{helper}{GetInProgress} = "0";
        GroheOndusSmartDevice_UpdateInternals($hash);

        readingsBulkUpdateIfChanged($hash, "LastDataTimestamp", $currentDataTimestamp_LUTC, 1)
          if(defined($currentDataTimestamp_LUTC));
        readingsBulkUpdateIfChanged($hash, "LastHumidity", $currentDataHumidity, 1)
          if(defined($currentDataHumidity));
        readingsBulkUpdateIfChanged($hash, "LastTemperature", $currentDataTemperature, 1)
          if(defined($currentDataTemperature));
          
        readingsEndUpdate( $hash, 1 );

        # if there is a callback then call it
        if( defined($callbackSuccess) )
        {
          Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackSuccess");
          $callbackSuccess->();
        }
      }
      else
      {
        # historic get still active
        $hash->{helper}{GetInProgress} = "1";
        GroheOndusSmartDevice_UpdateInternals($hash);

        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged( $hash, "state", "getting historic data $callbackparam->{requestToTimestamp_UTC}", 1 );
        readingsEndUpdate( $hash, 1 );

        # reload timer
        my $nextTimer = gettimeofday() + $GetLoopDataInterval;
        InternalTimer( $nextTimer, "GroheOndusSmartDevice_Sense_GetData_TimerExecute", 
          [$hash, 
          $callbackparam->{requestToTimestamp_UTC}, 
          $callbackparam->{GetCampain}, 
          $callbackSuccess, 
          $callbackFail]
        );
      }
    }
    else
    {
      # error -> historic get has broken
      #$hash->{helper}{GetInProgress} = "0";
      #GroheOndusSmartDevice_UpdateInternals($hash);

      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  # if there is a timer remove it
  GroheOndusSmartDevice_Sense_GetData_TimerRemove($hash);

  my $deviceId          = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if(defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $lastTDT_LUTC      = $hash->{helper}{ApplianceTDT_LUTC_GetData};
    my $applianceTDT_LUTC = $hash->{helper}{ApplianceTDT_LUTC};
    
    if($hash->{helper}{GetInProgress} ne "1" and              # only check if no campain is running
      $hash->{helper}{LastProcessedTimestamp_LUTC} ne "" and  # there is a LastProcessedTimestamp
      $hash->{helper}{OverrideCheckTDT} eq "0" and            # if check is disabled 
      $lastTDT_LUTC eq $applianceTDT_LUTC)                    # if TDT is processed
    {                                                         # -> don't get new data
      Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - no new TDT");

      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      # add offset in seconds to get to-timestamp
      my $requestToTimestamp_UTC_s = time_str2num($requestFromTimestamp_UTC) + $hash->{helper}{GetTimespan};
      my @t = localtime($requestToTimestamp_UTC_s);
      my $requestToTimestamp_UTC = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);

      my $param = {};
      $param->{method}                    = "GET";
      $param->{url}                       = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/data?from=" . $requestFromTimestamp_UTC . "&to=" . $requestToTimestamp_UTC;
      $param->{header}                    = "Content-Type: application/json";
      $param->{data}                      = "{}";
      $param->{httpversion}               = "1.0";
      $param->{ignoreredirects}           = 0;
      $param->{keepalive}                 = 1;
      $param->{timeout}                   = 10;
      $param->{incrementalTimeout}        = 1;

      $param->{resultCallback}            = $resultCallback;
      $param->{requestFromTimestamp_UTC}  = $requestFromTimestamp_UTC;
      $param->{requestToTimestamp_UTC}    = $requestToTimestamp_UTC;
      $param->{GetCampain}                = $hash->{helper}{GetCampain};
      $param->{ApplianceTDT_LUTC_GetData} = $applianceTDT_LUTC;
      $param->{timestampStart}            = gettimeofday();

      # set historic get to active
      $hash->{helper}{GetInProgress}            = "1";
      $hash->{helper}{Telegram_GetDataIOWrite}  = strftime($TimeStampFormat, localtime($param->{timestampStart}));
      GroheOndusSmartDevice_UpdateInternals($hash);

      GroheOndusSmartDevice_IOWrite( $hash, $param );
    }
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData($name) - callbackFail");
      $callbackFail->();
    }
  }
}


##################################
# GroheOndusSmartDevice_Sense_GetData_Last( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Sense_GetData_Last($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  if($hash->{helper}{GetInProgress} eq "1")
  {
    Log3($name, 5, "GroheOndusSmartDevice_Sense_GetData_Last($name) - GetInProgress");
  }
  else
  {
    my $requestFromTimestamp_UTC      = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{LastProcessedTimestamp_LUTC});
    my $applianceTDT_UTC              = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{ApplianceTDT_LUTC});
    my $getHistoricDataStartDate_UTC  = GroheOndusSmartDevice_GetUTCFromLTZ($hash->{helper}{LogFileGetDataStartDate_LTZ});

    if(not defined($requestFromTimestamp_UTC))
    {
      $requestFromTimestamp_UTC = GroheOndusSmartDevice_GetUTCMidnightDate(0);
    }
    elsif(defined($getHistoricDataStartDate_UTC) and
      $getHistoricDataStartDate_UTC gt $requestFromTimestamp_UTC)
    {
      $requestFromTimestamp_UTC = $getHistoricDataStartDate_UTC;
    }

    if($requestFromTimestamp_UTC lt $applianceTDT_UTC)
    {
      Log3($name, 5, "GroheOndusSmartDevice_Sense_GetData_Last($name) - requestFromTimestamp_UTC: $requestFromTimestamp_UTC");

      $hash->{helper}{GetCampain}++;                                  # new campain-counter to stop current running old campains

      GroheOndusSmartDevice_Sense_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);
    }
    else
    {
      Log3($name, 5, "GroheOndusSmartDevice_Sense_GetData_Last($name) - requestFromTimestamp_UTC: $requestFromTimestamp_UTC > applianceTDT: $applianceTDT_UTC");
    }
  }
}

##################################
# GroheOndusSmartDevice_Sense_GetData_Stop($)
sub GroheOndusSmartDevice_Sense_GetData_Stop($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};

  if($hash->{helper}{GetInProgress} eq "1")
  {
    Log3($name, 5, "GroheOndusSmartDevice_Sense_GetData_Stop($name)");
    
    GroheOndusSmartDevice_Sense_GetData_TimerRemove($hash);

    $hash->{helper}{GetInProgress}                = "0";
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    $hash->{helper}{GetSuspendReadings}           = "0";  # suspend readings
    $hash->{helper}{GetCampain}++;                        # new campain-counter to stop current running old campains
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Sense_GetData_StartCampain", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

    GroheOndusSmartDevice_UpdateInternals($hash);

    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged($hash, "state", "getting historic data stopped", 1);
    readingsEndUpdate($hash, 1);
  }
}

##################################
# GroheOndusSmartDevice_Sense_GetData_StartCampain( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Sense_GetData_StartCampain($$;$$)
{
  my ( $hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};
  
  $hash->{helper}{LogFileName}                  = "";   # reset internal to delete existing file
  $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";   # reset internal to restart processing
  $hash->{helper}{GetCampain}++;                        # new campain-counter to stop current running old campains

  $hash->{helper}{GetSuspendReadings}           = "1";  # suspend readings
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Sense_GetData_StartCampain", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

  GroheOndusSmartDevice_Sense_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);
}

##################################
# GroheOndusSmartDevice_Sense_GetData_TimerExecute( @args )
sub GroheOndusSmartDevice_Sense_GetData_TimerExecute($)
{
  my ( $args ) = @_;
  my ( $hash, $requestFromTimestamp_UTC, $getCampain, $callbackSuccess, $callbackFail ) = @{$args};
  my $name = $hash->{NAME};

  if($getCampain != $hash->{helper}{GetCampain})
  {
    Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData_TimerExecute($name) - dropping old Campain");

    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Sense_GetData_TimerExecute($name) - callbackFail");
      $callbackFail->();
    }
  }
  else
  {
    GroheOndusSmartDevice_Sense_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);  
  }
}

##################################
# GroheOndusSmartDevice_Sense_GetData_TimerRemove( @args )
sub GroheOndusSmartDevice_Sense_GetData_TimerRemove($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};
  
  my $functionName = "GroheOndusSmartDevice_Sense_GetData_TimerExecute"; 
  Log3($name, 5, "GroheOndusSmartDevice_Sense_GetData_TimerRemove($name) - $functionName");
  
  RemoveInternalTimer($hash, $functionName);
}

#####################################
# GroheOndusSmartDevice_Sense_Set( $hash, $name, $cmd, @args )
sub GroheOndusSmartDevice_Sense_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  ### Command "update"
  if( lc $cmd eq lc "update" )
  {
    GroheOndusSmartDevice_Sense_Update($hash);
    return;
  }
  ### Command "clearreadings"
  elsif( lc $cmd eq lc "clearreadings" )
  {
    fhem("deletereading $name .*", 1);
    return;
  }
  ### Command "logFileDelete"
  elsif( lc $cmd eq lc "logFileDelete" )
  {
    my $logFileName = $hash->{helper}{LogFileName};
    GroheOndusSmartDevice_FileLog_Delete($hash, $logFileName);
    return;
  }
  ### Command "logFileGetHistoricData"
  elsif( lc $cmd eq lc "logFileGetHistoricData" )
  {
    my $value = "";
    my $requestFromTimestamp_UTC = "";

    $value = $args[0]
      if(@args == 1);

    if(lc $value eq lc "stop")
    {
      GroheOndusSmartDevice_Sense_GetData_Stop($hash);
    }
    else
    {
      my $getHistoricDataStartDate_UTC = GroheOndusSmartDevice_GetUTCFromLTZ($hash->{helper}{LogFileGetDataStartDate_LTZ});
      my $applianceInstallationDate_UTC = GroheOndusSmartDevice_GetUTCFromLUTC(ReadingsVal($name, "ApplianceInstallationDate", undef));
      
      if($value eq "")
      {
        if(defined($getHistoricDataStartDate_UTC))
        {
          $requestFromTimestamp_UTC = $getHistoricDataStartDate_UTC;
        }
        elsif(defined($applianceInstallationDate_UTC))
        {
          $requestFromTimestamp_UTC = $applianceInstallationDate_UTC;
        }
      }
      else
      {
        # try to parse $value to timestamp
        my $timestampLocal_s = str2time($value);

        if(not defined($timestampLocal_s))
        {
          return "illegal format";
        }

        my @t = localtime($timestampLocal_s);
        $requestFromTimestamp_UTC = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
        
        # limit to applianceInstallationDate
        if(defined($applianceInstallationDate_UTC) and
          $requestFromTimestamp_UTC lt $applianceInstallationDate_UTC)
        {
          $requestFromTimestamp_UTC = $applianceInstallationDate_UTC;
        }
      }

      if(defined($requestFromTimestamp_UTC) and
        $requestFromTimestamp_UTC ne "")
      {
        GroheOndusSmartDevice_Sense_GetData_StartCampain($hash, $requestFromTimestamp_UTC);
      }
    }

    return;
  }
  ### Command "logFileCreateFileLogDevice"
  elsif( lc $cmd eq lc "logFileCreateFileLogDevice" )
  {
    my $logFileName = "";
    
    return "usage: $cmd [<devicename>]"
      if( @args > 1 );
    
    $logFileName = ($args[0] =~ tr/ //ds)         # trim whitespaces
      if( @args == 1 );
    
    GroheOndusSmartDevice_FileLog_Create_FileLogDevice($hash, $logFileName);
    
    return;
  }
  ### Command "debugRefreshValues"
  elsif( lc $cmd eq lc "debugRefreshValues" )
  {
    GroheOndusSmartDevice_Sense_GetData_Last($hash);
    return;
  }
  ### Command "debugRefreshState"
  elsif( lc $cmd eq lc "debugRefreshState" )
  {
    GroheOndusSmartDevice_Sense_GetState($hash);
    return;
  }
  ### Command "debugRefreshConfig"
  elsif( lc $cmd eq lc "debugRefreshConfig" )
  {
    GroheOndusSmartDevice_Sense_GetConfig($hash);
    return;
  }
  ### Command "debugOverrideCheckTDT"
  elsif( lc $cmd eq lc "debugOverrideCheckTDT" )
  {
    $hash->{helper}{OverrideCheckTDT} = join( " ", @args );
    GroheOndusSmartDevice_UpdateInternals($hash);
    return;
  }
  ### Command "debugResetProcessedMeasurementTimestamp"
  elsif( lc $cmd eq lc "debugResetProcessedMeasurementTimestamp" )
  {
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    GroheOndusSmartDevice_UpdateInternals($hash);
    return;
  }
  ### Command "debugForceUpdate"
  elsif( lc $cmd eq lc "debugForceUpdate" )
  {
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    GroheOndusSmartDevice_UpdateInternals($hash);
    
    GroheOndusSmartDevice_TimerExecute($hash);
    return;
  }
  ### unknown Command
  else
  {
    my $list = "";
    
    $list .= "update:noArg ";
    $list .= "clearreadings:noArg ";
    
    $list .= "logFileDelete:noArg "
      if($hash->{helper}{LogFileEnabled} ne "0" and  # check if in logfile mode
      defined($hash->{helper}{LogFileName}) and      # check if filename is defined
      -e $hash->{helper}{LogFileName});              # check if file exists

    my $logFileGetHistoricDataArgs = "";
    if($hash->{helper}{GetSuspendReadings} ne "0")
    {
      $logFileGetHistoricDataArgs = "stop";
    }
    $list .= "logFileGetHistoricData:$logFileGetHistoricDataArgs "
      if($hash->{helper}{LogFileEnabled} ne "0");     # check if in logfile mode

    $list .= "logFileCreateFileLogDevice "
      if($hash->{helper}{LogFileEnabled} ne "0");     # check if in logfile mode

    $list .= "debugRefreshConfig:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugRefreshValues:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugRefreshState:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugOverrideCheckTDT:0,1 "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugResetProcessedMeasurementTimestamp:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugForceUpdate:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    return "Unknown argument $cmd, choose one of $list";
  }
}

##################################
# GroheOndusSmartDevice_Blue_Update( $hash )
sub GroheOndusSmartDevice_Blue_Update($)
{
  my ( $hash ) = @_;
  my $name     = $hash->{NAME};

  Log3($name, 4, "GroheOndusSmartDevice_Blue_Update($name)");

  # parallel call:
  #GroheOndusSmartDevice_Blue_GetData($hash);
  #GroheOndusSmartDevice_Blue_GetState($hash);
  #GroheOndusSmartDevice_Blue_GetConfig($hash);
  
  # serial call:
  my $getApplianceCommand = sub { GroheOndusSmartDevice_Blue_GetApplianceCommand($hash); };
  my $getData             = sub { GroheOndusSmartDevice_Blue_GetData_Last($hash, $getApplianceCommand); };
  my $getState            = sub { GroheOndusSmartDevice_Blue_GetState($hash, $getData); };
  my $getConfig           = sub { GroheOndusSmartDevice_Blue_GetConfig($hash, $getState); };
  
  $getConfig->();
}

##################################
# GroheOndusSmartDevice_Blue_GetState( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Blue_GetState($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name     = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetStateTimeRequest} = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetStateCallback}    = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_Blue_GetState($name) - resultCallback");

    if( $errorMsg eq "")
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "State_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Blue_GetState($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "State_JSON_ERROR", $@, 1 );
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
        if( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          foreach my $currentData ( @{ $decode_json } )
          {
            if( $currentData->{type} eq "update_available"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateUpdateAvailable", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "battery"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateBattery", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "connection"
              and defined( $currentData->{value} ) )
            {
              readingsBulkUpdateIfChanged( $hash, "StateConnection", $currentData->{value} );
            } 
            elsif( $currentData->{type} eq "wifi_quality"
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

          $hash->{helper}{Telegram_GetStateCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetStateTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if($errorMsg eq "")
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetState($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetState($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/status";
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;

    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();

    $hash->{helper}{Telegram_GetStateIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Blue_GetState($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_Blue_GetConfig( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Blue_GetConfig($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetConfigTimeRequest} = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetConfigCallback}    = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_Blue_GetConfig($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "Config_RAW", "\"" . $data . "\"", 1 );
      }
      
      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Blue_GetConfig($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "Config_JSON_ERROR", $@, 1 );
        }
        $errorMsg = "GETConfig_JSON_ERROR";
      }
      else
      {
      #[
      #{
      #   "appliance_id":"6b2fe87a-353c-4489-8504-83aad2fb9b83",
      #   "installation_date":"2023-07-26T18:28:53.000+02:00",
      #   "name":"Mein Grohe",
      #   "serial_number":"---------------------------------------------",
      #   "type":104,
      #   "version":"01.04.Z10.0300.0104",
      #   "tdt":"2023-08-02T22:01:31.000+02:00",
      #   "timezone":60,
      #   "role":"owner",
      #   "registration_complete":true,
      #   "presharedkey":"--------------",
      #   "config":
      #   {
      #     "co2_type":1,
      #     "hose_length":70,
      #     "co2_consumption_medium":48,
      #     "co2_consumption_carbonated":65,
      #     "guest_mode_active":false,
      #     "auto_flush_active":false,
      #     "flush_confirmed":false,
      #     "f_parameter":3,
      #     "l_parameter":0,
      #     "flow_rate_still":18,
      #     "flow_rate_medium":24,
      #     "flow_rate_carbonated":18
      #   },
      #   "params":
      #   {
      #     "water_hardness":0,
      #     "carbon_hardness":20,
      #     "filter_type":1,
      #     "variant":4,
      #     "auto_flush_reminder_notif":true,
      #     "consumables_low_notif":true,
      #     "product_information_notif":true
      #   },
      #   "error":
      #   {
      #     "errors_1":false,
      #     "errors_2":false,
      #     "errors_3":false,
      #     "errors_4":false,
      #     "errors_5":false,
      #     "errors_6":false,
      #     "errors_7":false,
      #     "errors_8":false,
      #     "errors_9":false,
      #     "errors_10":false,
      #     "errors_11":false,
      #     "errors_12":false,
      #     "errors_13":false,
      #     "errors_14":false,
      #     "errors_15":false,
      #     "errors_16":false,
      #     "error1_counter":768,
      #     "error2_counter":256,
      #     "error3_counter":0,
      #     "error4_counter":0,
      #     "error5_counter":0,
      #     "error6_counter":0,
      #     "error7_counter":0,
      #     "error8_counter":0,
      #     "error9_counter":0,
      #     "error10_counter":0,
      #     "error11_counter":0,
      #     "error12_counter":5888,
      #     "error13_counter":0,
      #     "error14_counter":0,
      #     "error15_counter":0,
      #     "error16_counter":0
      #   },
      #   "state":
      #   {
      #     "start_time":1691006535,
      #     "APPLIANCE_SUCCESSFUL_CONFIGURED":false,
      #     "co2_empty":false,
      #     "co2_20l_reached":false,
      #     "filter_empty":false,
      #     "filter_20l_reached":false,
      #     "cleaning_mode_active":false,
      #     "cleaning_needed":false,
      #     "flush_confirmation_required":false,
      #     "System_error_bitfield":0
      #   }
      # }
      #]

        if( defined( $decode_json )
          and ref( $decode_json ) eq "ARRAY" )
        {
          #   "appliance_id":"6b2fe87a-353c-4489-8504-83aad2fb9b83",
          #   "installation_date":"2023-07-26T18:28:53.000+02:00",
          #   "name":"Mein Grohe",
          #   "serial_number":"---------------------------------------------",
          #   "type":104,
          #   "version":"01.04.Z10.0300.0104",
          #   "tdt":"2023-08-02T22:01:31.000+02:00",
          #   "timezone":60,
          #   "role":"owner",
          #   "registration_complete":true,
          #   "presharedkey":"--------------",

          my $currentEntry = $decode_json->[0];

          if( defined( $currentEntry )
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
            readingsBulkUpdateIfChanged( $hash, "AppliancePresharedkey", "$currentEntry->{presharedkey}" )
              if( defined( $currentEntry->{presharedkey} ) );

            $hash->{helper}{ApplianceTDT_LUTC} = "$currentEntry->{tdt}"
              if( defined( $currentEntry->{tdt} ) );

            my $currentConfig = $currentEntry->{config};

            if( defined( $currentConfig )
              and ref( $currentConfig ) eq "HASH" )
            {

            #   "config":
            #   {
            #     "co2_type":1,
            #     "hose_length":70,
            #     "co2_consumption_medium":48,
            #     "co2_consumption_carbonated":65,
            #     "guest_mode_active":false,
            #     "auto_flush_active":false,
            #     "flush_confirmed":false,
            #     "f_parameter":3,
            #     "l_parameter":0,
            #     "flow_rate_still":18,
            #     "flow_rate_medium":24,
            #     "flow_rate_carbonated":18
            #   },
              readingsBulkUpdateIfChanged( $hash, "Config_co2_type", "$currentConfig->{co2_type}" )
                if( defined( $currentConfig->{co2_type} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_hose_length", "$currentConfig->{hose_length}" )
                if( defined( $currentConfig->{hose_length} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_co2_consumption_medium", "$currentConfig->{co2_consumption_medium}" )
                if( defined( $currentConfig->{co2_consumption_medium} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_cco2_consumption_carbonated", "$currentConfig->{co2_consumption_carbonated}" )
                if( defined( $currentConfig->{co2_consumption_medium} ) );
              readingsBulkUpdateIfChanged( $hash, "co2_guest_mode_active", "$currentConfig->{guest_mode_active}" )
                if( defined( $currentConfig->{guest_mode_active} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_auto_flush_active", "$currentConfig->{auto_flush_active}" )
                if( defined( $currentConfig->{auto_flush_active} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_flush_confirmed", "$currentConfig->{flush_confirmed}" )
                if( defined( $currentConfig->{flush_confirmed} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_f_parameter", "$currentConfig->{f_parameter}" )
                if( defined( $currentConfig->{f_parameter} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_l_parameter", "$currentConfig->{l_parameter}" )
                if( defined( $currentConfig->{l_parameter} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_flow_rate_still", "$currentConfig->{flow_rate_still}" )
                if( defined( $currentConfig->{flow_rate_still} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_flow_rate_medium", "$currentConfig->{flow_rate_medium}" )
                if( defined( $currentConfig->{flow_rate_medium} ) );
              readingsBulkUpdateIfChanged( $hash, "Config_flow_rate_carbonated", "$currentConfig->{flow_rate_carbonated}" )
                if( defined( $currentConfig->{flow_rate_carbonated} ) );
            }

            my $currentParams = $currentEntry->{params};

            if( defined( $currentParams )
              and ref( $currentParams ) eq "HASH" )
            {
              #   "params":
              #   {
              #     "water_hardness":0,
              #     "carbon_hardness":20,
              #     "filter_type":1,
              #     "variant":4,
              #     "auto_flush_reminder_notif":true,
              #     "consumables_low_notif":true,
              #     "product_information_notif":true
              #   },

              readingsBulkUpdateIfChanged( $hash, "Params_water_hardness", "$currentParams->{water_hardness}" )
                if( defined( $currentParams->{water_hardness} ) );
              readingsBulkUpdateIfChanged( $hash, "Params_carbon_hardness", "$currentParams->{carbon_hardness}" )
                if( defined( $currentParams->{carbon_hardness} ) );
              readingsBulkUpdateIfChanged( $hash, "Params_filter_type", "$currentParams->{filter_type}" )
                if( defined( $currentParams->{filter_type} ) );
              readingsBulkUpdateIfChanged( $hash, "Params_variant", "$currentParams->{variant}" )
                if( defined( $currentParams->{variant} ) );
              readingsBulkUpdateIfChanged( $hash, "Params_auto_flush_reminder_notif", "$currentParams->{auto_flush_reminder_notif}" )
                if( defined( $currentParams->{auto_flush_reminder_notif} ) );
              readingsBulkUpdateIfChanged( $hash, "Params_consumables_low_notif", "$currentParams->{water_consumables_low_notif}" )
                if( defined( $currentParams->{consumables_low_notif} ) );
              readingsBulkUpdateIfChanged( $hash, "Params_product_information_notif", "$currentParams->{product_information_notif}" )
                if( defined( $currentParams->{product_information_notif} ) );
            }

            my $currentState = $currentEntry->{"state"};

            if( defined( $currentState )
              and ref( $currentState ) eq "HASH" )
            {
              #   "state":
              #   {
              #     "start_time":1691006535,
              #     "APPLIANCE_SUCCESSFUL_CONFIGURED":false,
              #     "co2_empty":false,
              #     "co2_20l_reached":false,
              #     "filter_empty":false,
              #     "filter_20l_reached":false,
              #     "cleaning_mode_active":false,
              #     "cleaning_needed":false,
              #     "flush_confirmation_required":false,
              #     "System_error_bitfield":0
              #   }
              readingsBulkUpdateIfChanged( $hash, "State_start_time", "$currentState->{start_time}" )
                if( defined( $currentState->{start_time} ) );
              readingsBulkUpdateIfChanged( $hash, "State_APPLIANCE_SUCCESSFUL_CONFIGURED", "$currentState->{APPLIANCE_SUCCESSFUL_CONFIGURED}" )
                if( defined( $currentState->{APPLIANCE_SUCCESSFUL_CONFIGURED} ) );
              readingsBulkUpdateIfChanged( $hash, "State_co2_empty", "$currentState->{co2_empty}" )
                if( defined( $currentState->{co2_empty} ) );
              readingsBulkUpdateIfChanged( $hash, "State_co2_20l_reached", "$currentState->{co2_20l_reached}" )
                if( defined( $currentState->{co2_20l_reached} ) );
              readingsBulkUpdateIfChanged( $hash, "State_filter_empty", "$currentState->{filter_empty}" )
                if( defined( $currentState->{filter_empty} ) );
              readingsBulkUpdateIfChanged( $hash, "State_filter_20l_reached", "$currentState->{filter_20l_reached}" )
                if( defined( $currentState->{filter_20l_reached} ) );
              readingsBulkUpdateIfChanged( $hash, "State_cleaning_mode_active", "$currentState->{cleaning_mode_active}" )
                if( defined( $currentState->{cleaning_mode_active} ) );
              readingsBulkUpdateIfChanged( $hash, "State_cleaning_needed", "$currentState->{cleaning_needed}" )
                if( defined( $currentState->{cleaning_needed} ) );
              readingsBulkUpdateIfChanged( $hash, "State_flush_confirmation_required", "$currentState->{flush_confirmation_required}" )
                if( defined( $currentState->{flush_confirmation_required} ) );
              readingsBulkUpdateIfChanged( $hash, "State_System_error_bitfield", "$currentState->{System_error_bitfield}" )
                if( defined( $currentState->{System_error_bitfield} ) );
            }

            my $currentError = $currentEntry->{"error"};

            if( defined( $currentError )
              and ref( $currentError ) eq "HASH" )
            {

              #   "error":
              #   {
              #     "errors_1":false,
              #     "errors_2":false,
              #     "errors_3":false,
              #     "errors_4":false,
              #     "errors_5":false,
              #     "errors_6":false,
              #     "errors_7":false,
              #     "errors_8":false,
              #     "errors_9":false,
              #     "errors_10":false,
              #     "errors_11":false,
              #     "errors_12":false,
              #     "errors_13":false,
              #     "errors_14":false,
              #     "errors_15":false,
              #     "errors_16":false,
              #     "error1_counter":768,
              #     "error2_counter":256,
              #     "error3_counter":0,
              #     "error4_counter":0,
              #     "error5_counter":0,
              #     "error6_counter":0,
              #     "error7_counter":0,
              #     "error8_counter":0,
              #     "error9_counter":0,
              #     "error10_counter":0,
              #     "error11_counter":0,
              #     "error12_counter":5888,
              #     "error13_counter":0,
              #     "error14_counter":0,
              #     "error15_counter":0,
              #     "error16_counter":0
              #   },
              readingsBulkUpdateIfChanged( $hash, "Error_errors_1", "$currentError->{errors_1}" )
                if( defined( $currentError->{errors_1} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_2", "$currentError->{errors_2}" )
                if( defined( $currentError->{errors_2} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_3", "$currentError->{errors_3}" )
                if( defined( $currentError->{errors_3} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_4", "$currentError->{errors_4}" )
                if( defined( $currentError->{errors_4} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_5", "$currentError->{errors_5}" )
                if( defined( $currentError->{errors_5} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_6", "$currentError->{errors_6}" )
                if( defined( $currentError->{errors_6} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_7", "$currentError->{errors_7}" )
                if( defined( $currentError->{errors_7} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_8", "$currentError->{errors_8}" )
                if( defined( $currentError->{errors_8} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_9", "$currentError->{errors_9}" )
                if( defined( $currentError->{errors_9} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_10", "$currentError->{errors_10}" )
                if( defined( $currentError->{errors_10} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_11", "$currentError->{errors_11}" )
                if( defined( $currentError->{errors_11} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_12", "$currentError->{errors_12}" )
                if( defined( $currentError->{errors_12} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_13", "$currentError->{errors_13}" )
                if( defined( $currentError->{errors_13} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_14", "$currentError->{errors_14}" )
                if( defined( $currentError->{errors_14} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_15", "$currentError->{errors_15}" )
                if( defined( $currentError->{errors_15} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_errors_16", "$currentError->{errors_16}" )
                if( defined( $currentError->{errors_16} ) );

              readingsBulkUpdateIfChanged( $hash, "Error_error1_counter", "$currentError->{error1_counter}" )
                if( defined( $currentError->{error1_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error2_counter", "$currentError->{error2_counter}" )
                if( defined( $currentError->{error2_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error3_counter", "$currentError->{error3_counter}" )
                if( defined( $currentError->{error3_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error4_counter", "$currentError->{error4_counter}" )
                if( defined( $currentError->{error4_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error5_counter", "$currentError->{error5_counter}" )
                if( defined( $currentError->{error5_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error6_counter", "$currentError->{error6_counter}" )
                if( defined( $currentError->{error6_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error7_counter", "$currentError->{error7_counter}" )
                if( defined( $currentError->{error7_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error8_counter", "$currentError->{error8_counter}" )
                if( defined( $currentError->{error8_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error9_counter", "$currentError->{error9_counter}" )
                if( defined( $currentError->{error9_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error10_counter", "$currentError->{error10_counter}" )
                if( defined( $currentError->{error10_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error11_counter", "$currentError->{error11_counter}" )
                if( defined( $currentError->{error11_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error12_counter", "$currentError->{error12_counter}" )
                if( defined( $currentError->{error12_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error13_counter", "$currentError->{error13_counter}" )
                if( defined( $currentError->{error13_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error14_counter", "$currentError->{error14_counter}" )
                if( defined( $currentError->{error14_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error15_counter", "$currentError->{error15_counter}" )
                if( defined( $currentError->{error15_counter} ) );
              readingsBulkUpdateIfChanged( $hash, "Error_error16_counter", "$currentError->{error16_counter}" )
                if( defined( $currentError->{error16_counter} ) );
            }
          }

          $hash->{helper}{Telegram_GetConfigCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetConfigTimeProcess}  = gettimeofday() - $stopwatch;
    GroheOndusSmartDevice_UpdateInternals($hash);

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetConfig($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetConfig($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId;
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_GetConfigIOWrite} = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Blue_GetConfig($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_Blue_GetData( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Blue_GetData($$;$$)
{
  my ( $hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail ) = @_;
  my $name     = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetDataTimeRequest}  = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetDataCallback}     = strftime($TimeStampFormat, localtime($stopwatch));
    $hash->{helper}{Telegram_GetDataCampain}      = $callbackparam->{GetCampain};
    Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - resultCallback");

    my $lastProcessedTimestamp_LUTC = $hash->{helper}{LastProcessedTimestamp_LUTC};
    
    my $currentDataTimestamp_LUTC              = undef;
    my $current_open_close_cycles_still        = undef;
    my $current_open_close_cycles_carbonated   = undef;
    my $current_water_running_time_still       = undef;
    my $current_water_running_time_medium      = undef;
    my $current_water_running_time_carbonated  = undef;
    my $current_operating_time                 = undef;
    my $current_max_idle_time                  = undef;
    my $current_pump_count                     = undef;
    my $current_pump_running_time              = undef;
    my $current_remaining_filter               = undef;
    my $current_remaining_co2                  = undef;
    my $current_date_of_filter_replacement     = undef;
    my $current_date_of_co2_replacement        = undef;
    my $current_date_of_cleaning               = undef;
    my $current_power_cut_count                = undef;
    my $current_time_since_restart             = undef;
    my $current_time_since_last_withdrawal     = undef;
    my $current_filter_change_count            = undef;
    my $current_cleaning_count                 = undef;

    if($callbackparam->{GetCampain} != $hash->{helper}{GetCampain})
    {
      $errorMsg = "GetData old Campain";
    }
    elsif( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "Data_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Blue_GetData($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "Data_JSON_ERROR", $@, 1 );
        }
        $errorMsg = "GetHistoricData_JSON_ERROR";
      }
      else
      {
        $hash->{helper}{ApplianceTDT_LUTC_GetData} = $callbackparam->{ApplianceTDT_LUTC_GetData};

        # Data:
        # {
        #   "data":
        #   {
        #     "measurement":
        #     [
        #       {
        #         "timestamp":"2023-08-06T00:18:06.000+02:00",
        #         "open_close_cycles_still":173,
        #         "open_close_cycles_carbonated":165,
        #         "water_running_time_still":5,
        #         "water_running_time_medium":2,
        #         "water_running_time_carbonated":22,
        #         "operating_time":245,
        #         "max_idle_time":1003,
        #         "pump_count":271,
        #         "pump_running_time":45,
        #         "remaining_filter":759,
        #         "remaining_co2":34,
        #         "date_of_filter_replacement":"2023-07-26T19:55:21.000+02:00",
        #         "date_of_co2_replacement":"2023-07-28T22:23:55.000+02:00",
        #         "date_of_cleaning":"2023-07-26T17:33:15.000+02:00",
        #         "power_cut_count":18,
        #         "time_since_restart":536887329,
        #         "time_since_last_withdrawal":57,
        #         "filter_change_count":0,
        #         "cleaning_count":0
        #       },
        #     ],
        #     "withdrawals":
        #     [
        #     ]
        #   }
        # } 

        if( defined( $decode_json ) and
          defined( $decode_json->{data}->{measurement} ) and
          ref( $decode_json->{data}->{measurement} ) eq "ARRAY" )
        {
          # get entry with latest timestamp
          my $dataTimestamp = undef;
          my $loopCounter = 0;

          foreach my $currentData ( @{ $decode_json->{data}->{measurement} } )
          {
            # is this the correct dataset?
            if( defined( $currentData->{timestamp} ) and 
              defined( $currentData->{open_close_cycles_still} ) and 
              defined( $currentData->{open_close_cycles_carbonated} ) and 
              defined( $currentData->{water_running_time_still} ) and 
              defined( $currentData->{water_running_time_medium} ) and 
              defined( $currentData->{water_running_time_carbonated} ) and 
              defined( $currentData->{operating_time} ) and 
              defined( $currentData->{max_idle_time} ) and 
              defined( $currentData->{pump_count} ) and 
              defined( $currentData->{pump_running_time} ) and 
              defined( $currentData->{remaining_filter} ) and 
              defined( $currentData->{remaining_co2} ) and 
              defined( $currentData->{date_of_filter_replacement} ) and 
              defined( $currentData->{date_of_co2_replacement} ) and 
              defined( $currentData->{date_of_cleaning} ) and 
              defined( $currentData->{power_cut_count} ) and 
              defined( $currentData->{time_since_restart} ) and 
              defined( $currentData->{time_since_last_withdrawal} ) and 
              defined( $currentData->{filter_change_count} ) and 
              defined( $currentData->{cleaning_count} ) )
            {
              $currentDataTimestamp_LUTC              = $currentData->{timestamp};
              $current_open_close_cycles_still        = $currentData->{open_close_cycles_still};
              $current_open_close_cycles_carbonated   = $currentData->{open_close_cycles_carbonated};
              $current_water_running_time_still       = $currentData->{water_running_time_still};
              $current_water_running_time_medium      = $currentData->{water_running_time_medium};
              $current_water_running_time_carbonated  = $currentData->{water_running_time_carbonated};
              $current_operating_time                 = $currentData->{operating_time};
              $current_max_idle_time                  = $currentData->{max_idle_time};
              $current_pump_count                     = $currentData->{pump_count};
              $current_pump_running_time              = $currentData->{pump_running_time};
              $current_remaining_filter               = $currentData->{remaining_filter};
              $current_remaining_co2                  = $currentData->{remaining_co2};
              $current_date_of_filter_replacement     = $currentData->{date_of_filter_replacement};
              $current_date_of_co2_replacement        = $currentData->{date_of_co2_replacement};
              $current_date_of_cleaning               = $currentData->{date_of_cleaning};
              $current_power_cut_count                = $currentData->{power_cut_count};
              $current_time_since_restart             = $currentData->{time_since_restart};
              $current_time_since_last_withdrawal     = $currentData->{time_since_last_withdrawal};
              $current_filter_change_count            = $currentData->{filter_change_count};
              $current_cleaning_count                 = $currentData->{cleaning_count};
              
              # don't process measurevalues with timestamp before $lastProcessedTimestamp
              if($currentDataTimestamp_LUTC gt $lastProcessedTimestamp_LUTC)
              {
                # force the timestamp-seconds-string to have a well known length
                # fill with leading zeros
                my $currentDataTimestamp_LTZ = GroheOndusSmartDevice_GetLTZFromLUTC($currentDataTimestamp_LUTC);
                my $currentDataTimestamp_LTZ_s = time_str2num($currentDataTimestamp_LTZ);
                my $currentDataTimestamp_LTZ_s_string = GroheOndusSmartDevice_GetLTZStringFromLUTC($currentDataTimestamp_LUTC);

                if( $hash->{helper}{GetSuspendReadings} eq "0")
                {
                  readingsBeginUpdate($hash);
    
                  readingsBulkUpdateIfChanged( $hash, "MeasurementDataTimestamp", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $currentDataTimestamp_LUTC )
                    if( defined($currentDataTimestamp_LUTC) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_open_close_cycles_still", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_open_close_cycles_still )
                    if( defined($current_open_close_cycles_still) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_open_close_cycles_carbonated", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_open_close_cycles_carbonated )
                    if( defined($current_open_close_cycles_carbonated) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_water_running_time_still", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_water_running_time_still )
                    if( defined($current_water_running_time_still) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_water_running_time_medium", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_water_running_time_medium )
                    if( defined($current_water_running_time_medium) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_water_running_time_carbonated", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_water_running_time_carbonated )
                    if( defined($current_water_running_time_carbonated) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_operating_time", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_operating_time )
                    if( defined($current_operating_time) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_max_idle_time", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_max_idle_time )
                    if( defined($current_max_idle_time) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_pump_count", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_pump_count )
                    if( defined($current_pump_count) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_pump_running_time", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_pump_running_time )
                    if( defined($current_pump_running_time) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_remaining_filter", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_remaining_filter )
                    if( defined($current_remaining_filter) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_remaining_co2", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_remaining_co2 )
                    if( defined($current_remaining_co2) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_date_of_filter_replacement", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_date_of_filter_replacement )
                    if( defined($current_date_of_filter_replacement) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_date_of_co2_replacement", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_date_of_co2_replacement )
                    if( defined($current_date_of_co2_replacement) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_date_of_cleaning", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_date_of_cleaning )
                    if( defined($current_date_of_cleaning) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_power_cut_count", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_power_cut_count )
                    if( defined($current_power_cut_count) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_time_since_restart", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_time_since_restart )
                    if( defined($current_time_since_restart) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_time_since_last_withdrawal", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_time_since_last_withdrawal )
                    if( defined($current_time_since_last_withdrawal) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_filter_change_count", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_filter_change_count )
                    if( defined($current_filter_change_count) );
                  readingsBulkUpdateIfChanged( $hash, "Measurement_cleaning_count", $CurrentMeasurementFormatVersion . $currentDataTimestamp_LTZ_s_string . " " . $current_cleaning_count )
                    if( defined($current_cleaning_count) );

                  readingsEndUpdate( $hash, 1 );
                }

                # if enabled write MeasureValues to own FileLog
                GroheOndusSmartDevice_FileLog_MeasureValueWrite($hash, "Measurement", $currentDataTimestamp_LTZ_s, 
                  ["MeasurementDataTimestamp", $currentDataTimestamp_LUTC],
                  ["Measurement_open_close_cycles_still", $current_open_close_cycles_still],
                  ["Measurement_open_close_cycles_carbonated", $current_open_close_cycles_carbonated],
                  ["Measurement_water_running_time_still", $current_water_running_time_still],
                  ["Measurement_water_running_time_medium", $current_water_running_time_medium],
                  ["Measurement_water_running_time_carbonated", $current_water_running_time_carbonated],
                  ["Measurement_operating_time", $current_operating_time],
                  ["Measurement_max_idle_time", $current_max_idle_time],
                  ["Measurement_pump_count", $current_pump_count],
                  ["Measurement_pump_running_time", $current_pump_running_time],
                  ["Measurement_remaining_filter", $current_remaining_filter],
                  ["Measurement_remaining_co2", $current_remaining_co2],
                  ["Measurement_date_of_filter_replacement", $current_date_of_filter_replacement],
                  ["Measurement_date_of_co2_replacement", $current_date_of_co2_replacement],
                  ["Measurement_date_of_cleaning", $current_date_of_cleaning],
                  ["Measurement_power_cut_count", $current_power_cut_count],
                  ["Measurement_time_since_restart", $current_time_since_restart],
                  ["Measurement_time_since_last_withdrawal", $current_time_since_last_withdrawal],
                  ["Measurement_filter_change_count", $current_filter_change_count],
                  ["Measurement_cleaning_count", $current_cleaning_count])
                  if( $hash->{helper}{LogFileEnabled} eq "1" ); # only if LogFile in use
                
                $lastProcessedTimestamp_LUTC = $currentDataTimestamp_LUTC;
              }
            }
            $loopCounter++;
          }

          $hash->{helper}{LastProcessedTimestamp_LUTC}      = $lastProcessedTimestamp_LUTC;
          $hash->{helper}{Telegram_GetDataLoopMeasurement}  = $loopCounter;
          $hash->{helper}{Telegram_GetDataCounter}++;

          # save values in store
          GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Blue_GetData", "LastProcessedTimestamp_LUTC", $hash->{helper}{LastProcessedTimestamp_LUTC});
        }
        # {
        #   "code":404,
        #   "message":"Not found"
        # }
        elsif( defined( $decode_json ) and
          defined( $decode_json->{code} ) and
          defined( $decode_json->{message} ) )
        {
          my $errorCode = $decode_json->{code};
          my $errorMessage = $decode_json->{message};
          my $message = "TimeStamp: " . strftime($TimeStampFormat, localtime(gettimeofday())) . " Code: " . $errorCode . " Message: " . $decode_json->{message}; 

          # Not found -> no data in requested timespan
          if( $errorCode == 404 )
          {
            Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - $message");
            readingsSingleUpdate( $hash, "Message", $message, 1 );
          }
          # Too many requests 
          elsif($errorCode == 429)
          {
            Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - $message");
            readingsSingleUpdate( $hash, "Message", $message, 1 );
          }
          else
          {
            Log3($name, 3, "GroheOndusSmartDevice_Blue_GetData($name) - $message");
            readingsSingleUpdate( $hash, "Message", $message, 1 );
          }
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
      }
    }

    $hash->{helper}{Telegram_GetDataTimeProcess}  = gettimeofday() - $stopwatch;

    if($errorMsg eq "")
    {
      my $applianceTDT_UTC = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}->{ApplianceTDT_LUTC});

      # requested timespan contains TDT so break historic get
      if($callbackparam->{requestToTimestamp_UTC} gt $applianceTDT_UTC)
      {
        readingsBeginUpdate($hash);

        if($hash->{helper}{GetInProgress} ne "0" and 
          $hash->{helper}{GetSuspendReadings} ne "0")
        {
          readingsBulkUpdateIfChanged($hash, "state", "getting historic data finished", 1);
        }

        $hash->{helper}{GetSuspendReadings} = "0";
        GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Blue_GetData", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

        $hash->{helper}{GetInProgress} = "0";
        GroheOndusSmartDevice_UpdateInternals($hash);

        readingsBulkUpdateIfChanged($hash, "LastDataTimestamp", $currentDataTimestamp_LUTC, 1)
          if(defined($currentDataTimestamp_LUTC));
        readingsBulkUpdateIfChanged($hash, "Last_open_close_cycles_still", $current_open_close_cycles_still, 1)
          if(defined($current_open_close_cycles_still));
        readingsBulkUpdateIfChanged($hash, "Last_open_close_cycles_carbonated", $current_open_close_cycles_carbonated, 1)
          if(defined($current_open_close_cycles_carbonated));
        readingsBulkUpdateIfChanged($hash, "Last_water_running_time_still", $current_water_running_time_still, 1)
          if(defined($current_water_running_time_still));
        readingsBulkUpdateIfChanged($hash, "Last_water_running_time_medium", $current_water_running_time_medium, 1)
          if(defined($current_water_running_time_medium));
        readingsBulkUpdateIfChanged($hash, "Last_water_running_time_carbonated", $current_water_running_time_carbonated, 1)
          if(defined($current_water_running_time_carbonated));
        readingsBulkUpdateIfChanged($hash, "Last_operating_time", $current_operating_time, 1)
          if(defined($current_operating_time));
        readingsBulkUpdateIfChanged($hash, "Last_max_idle_time", $current_max_idle_time, 1)
          if(defined($current_max_idle_time));
        readingsBulkUpdateIfChanged($hash, "Last_pump_count", $current_pump_count, 1)
          if(defined($current_pump_count));
        readingsBulkUpdateIfChanged($hash, "Last_pump_running_time", $current_pump_running_time, 1)
          if(defined($current_pump_running_time));
        readingsBulkUpdateIfChanged($hash, "Last_remaining_filter", $current_remaining_filter, 1)
          if(defined($current_remaining_filter));
        readingsBulkUpdateIfChanged($hash, "Last_remaining_co2", $current_remaining_co2, 1)
          if(defined($current_remaining_co2));
        readingsBulkUpdateIfChanged($hash, "Last_date_of_filter_replacement", $current_date_of_filter_replacement, 1)
          if(defined($current_date_of_filter_replacement));
        readingsBulkUpdateIfChanged($hash, "Last_date_of_cleaning", $current_date_of_co2_replacement, 1)
          if(defined($current_date_of_co2_replacement));
        readingsBulkUpdateIfChanged($hash, "Last_power_cut_count", $current_date_of_cleaning, 1)
          if(defined($current_date_of_cleaning));
        readingsBulkUpdateIfChanged($hash, "Last_time_since_restart", $current_time_since_restart, 1)
          if(defined($current_time_since_restart));
        readingsBulkUpdateIfChanged($hash, "Last_time_since_last_withdrawal", $current_time_since_last_withdrawal, 1)
          if(defined($current_time_since_last_withdrawal));
        readingsBulkUpdateIfChanged($hash, "Last_filter_change_count", $current_filter_change_count, 1)
          if(defined($current_filter_change_count));
        readingsBulkUpdateIfChanged($hash, "Last_cleaning_count", $current_cleaning_count, 1)
          if(defined($current_cleaning_count));
          
        readingsEndUpdate( $hash, 1 );

        # if there is a callback then call it
        if( defined($callbackSuccess) )
        {
          Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - callbackSuccess");
          $callbackSuccess->();
        }
      }
      else
      {
        # historic get still active
        $hash->{helper}{GetInProgress} = "1";
        GroheOndusSmartDevice_UpdateInternals($hash);

        readingsBeginUpdate($hash);
        readingsBulkUpdateIfChanged( $hash, "state", "getting historic data $callbackparam->{requestToTimestamp_UTC}", 1 );
        readingsEndUpdate( $hash, 1 );

        # reload timer
        my $nextTimer = gettimeofday() + $GetLoopDataInterval;
        InternalTimer( $nextTimer, "GroheOndusSmartDevice_Blue_GetData_TimerExecute", 
          [$hash, 
          $callbackparam->{requestToTimestamp_UTC}, 
          $callbackparam->{GetCampain}, 
          $callbackSuccess, 
          $callbackFail]
        );
      }
    }
    else
    {
      # error -> historic get has broken
      #$hash->{helper}{GetInProgress} = "0";
      #GroheOndusSmartDevice_UpdateInternals($hash);

      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  # if there is a timer remove it
  GroheOndusSmartDevice_Blue_GetData_TimerRemove($hash);

  my $deviceId          = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if(defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $lastTDT_LUTC      = $hash->{helper}{ApplianceTDT_LUTC_GetData};
    my $applianceTDT_LUTC = $hash->{helper}{ApplianceTDT_LUTC};
    
    if($hash->{helper}{GetInProgress} ne "1" and              # only check if no campain is running
      $hash->{helper}{LastProcessedTimestamp_LUTC} ne "" and  # there is a LastProcessedTimestamp
      $hash->{helper}{OverrideCheckTDT} eq "0" and            # if check is disabled 
      $lastTDT_LUTC eq $applianceTDT_LUTC)                    # if TDT is processed
    {                                                         # -> don't get new data
      Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - no new TDT");

      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      # add offset in seconds to get to-timestamp
      my $requestToTimestamp_UTC_s = time_str2num($requestFromTimestamp_UTC) + $hash->{helper}{GetTimespan};
      my @t = localtime($requestToTimestamp_UTC_s);
      my $requestToTimestamp_UTC = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);

      my $param = {};
      $param->{method}                    = "GET";
      $param->{url}                       = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/data?from=" . $requestFromTimestamp_UTC . "&to=" . $requestToTimestamp_UTC;
      $param->{header}                    = "Content-Type: application/json";
      $param->{data}                      = "{}";
      $param->{httpversion}               = "1.0";
      $param->{ignoreredirects}           = 0;
      $param->{keepalive}                 = 1;
      $param->{timeout}                   = 10;
      $param->{incrementalTimeout}        = 1;

      $param->{resultCallback}            = $resultCallback;
      $param->{requestFromTimestamp_UTC}  = $requestFromTimestamp_UTC;
      $param->{requestToTimestamp_UTC}    = $requestToTimestamp_UTC;
      $param->{GetCampain}                = $hash->{helper}{GetCampain};
      $param->{ApplianceTDT_LUTC_GetData} = $applianceTDT_LUTC;
      $param->{timestampStart}            = gettimeofday();

      # set historic get to active
      $hash->{helper}{GetInProgress}            = "1";
      $hash->{helper}{Telegram_GetDataIOWrite}  = strftime($TimeStampFormat, localtime($param->{timestampStart}));
      GroheOndusSmartDevice_UpdateInternals($hash);

      GroheOndusSmartDevice_IOWrite( $hash, $param );
    }
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData($name) - callbackFail");
      $callbackFail->();
    }
  }
}

##################################
# GroheOndusSmartDevice_Blue_GetData_Last( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Blue_GetData_Last($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};

  if($hash->{helper}{GetInProgress} eq "1")
  {
    Log3($name, 5, "GroheOndusSmartDevice_Blue_GetData_Last($name) - GetInProgress");
  }
  else
  {
    my $requestFromTimestamp_UTC      = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{LastProcessedTimestamp_LUTC});
    my $applianceTDT_UTC              = GroheOndusSmartDevice_GetUTCFromLUTC($hash->{helper}{ApplianceTDT_LUTC});
    my $getHistoricDataStartDate_UTC  = GroheOndusSmartDevice_GetUTCFromLTZ($hash->{helper}{LogFileGetDataStartDate_LTZ});

    if(not defined($requestFromTimestamp_UTC))
    {
      $requestFromTimestamp_UTC = GroheOndusSmartDevice_GetUTCMidnightDate(0);
    }
    elsif(defined($getHistoricDataStartDate_UTC) and
      $getHistoricDataStartDate_UTC gt $requestFromTimestamp_UTC)
    {
      $requestFromTimestamp_UTC = $getHistoricDataStartDate_UTC;
    }

    if($requestFromTimestamp_UTC lt $applianceTDT_UTC)
    {
      Log3($name, 5, "GroheOndusSmartDevice_Blue_GetData_Last($name) - requestFromTimestamp_UTC: $requestFromTimestamp_UTC");

      $hash->{helper}{GetCampain}++;                                  # new campain-counter to stop current running old campains

      GroheOndusSmartDevice_Blue_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);
    }
    else
    {
      Log3($name, 5, "GroheOndusSmartDevice_Blue_GetData_Last($name) - requestFromTimestamp_UTC: $requestFromTimestamp_UTC > applianceTDT: $applianceTDT_UTC");
    }
  }
}

##################################
# GroheOndusSmartDevice_Blue_GetData_Stop($)
sub GroheOndusSmartDevice_Blue_GetData_Stop($)
{
  my ($hash) = @_;
  my $name = $hash->{NAME};

  if($hash->{helper}{GetInProgress} eq "1")
  {
    Log3($name, 5, "GroheOndusSmartDevice_Blue_GetData_Stop($name)");
    
    GroheOndusSmartDevice_Blue_GetData_TimerRemove($hash);

    $hash->{helper}{GetInProgress}                = "0";
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    $hash->{helper}{GetSuspendReadings}           = "0";  # suspend readings
    $hash->{helper}{GetCampain}++;                        # new campain-counter to stop current running old campains
    GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Blue_GetData_StartCampain", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

    GroheOndusSmartDevice_UpdateInternals($hash);

    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged($hash, "state", "getting historic data stopped", 1);
    readingsEndUpdate($hash, 1);
  }
}

##################################
# GroheOndusSmartDevice_Blue_GetData_StartCampain( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Blue_GetData_StartCampain($$;$$)
{
  my ( $hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail ) = @_;
  my $name = $hash->{NAME};
  
  $hash->{helper}{LogFileName}                  = "";   # reset internal to delete existing file
  $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";   # reset internal to restart processing
  $hash->{helper}{GetCampain}++;                        # new campain-counter to stop current running old campains

  $hash->{helper}{GetSuspendReadings}           = "1";  # suspend readings
  GroheOndusSmartDevice_Store($hash, "GroheOndusSmartDevice_Blue_GetData_StartCampain", "GetSuspendReadings", $hash->{helper}{GetSuspendReadings});

  GroheOndusSmartDevice_Blue_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);
}

##################################
# GroheOndusSmartDevice_Blue_GetData_TimerExecute( @args )
sub GroheOndusSmartDevice_Blue_GetData_TimerExecute($)
{
  my ( $args ) = @_;
  my ( $hash, $requestFromTimestamp_UTC, $getCampain, $callbackSuccess, $callbackFail ) = @{$args};
  my $name = $hash->{NAME};

  if($getCampain != $hash->{helper}{GetCampain})
  {
    Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData_TimerExecute($name) - dropping old Campain");

    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Blue_GetData_TimerExecute($name) - callbackFail");
      $callbackFail->();
    }
  }
  else
  {
    GroheOndusSmartDevice_Blue_GetData($hash, $requestFromTimestamp_UTC, $callbackSuccess, $callbackFail);  
  }
}

##################################
# GroheOndusSmartDevice_Blue_GetData_TimerRemove( @args )
sub GroheOndusSmartDevice_Blue_GetData_TimerRemove($)
{
  my ( $hash ) = @_;
  my $name = $hash->{NAME};
  
  my $functionName = "GroheOndusSmartDevice_Blue_GetData_TimerExecute"; 
  Log3($name, 5, "GroheOndusSmartDevice_Blue_GetData_TimerRemove($name) - $functionName");
  
  RemoveInternalTimer($hash, $functionName);
}

#####################################
# GroheOndusSmartDevice_Blue_Set( $hash, $name, $cmd, @args )
sub GroheOndusSmartDevice_Blue_Set($@)
{
  my ( $hash, $name, $cmd, @args ) = @_;

  ### Command "update"
  if( lc $cmd eq lc "update" )
  {
    GroheOndusSmartDevice_Blue_Update($hash);
    return;
  }
  ### Command "clearreadings"
  elsif( lc $cmd eq lc "clearreadings" )
  {
    fhem("deletereading $name .*", 1);
    return;
  }
  ### Command "logFileDelete"
  elsif( lc $cmd eq lc "logFileDelete" )
  {
    my $logFileName = $hash->{helper}{LogFileName};
    GroheOndusSmartDevice_FileLog_Delete($hash, $logFileName);
    return;
  }
  ### Command "logFileGetHistoricData"
  elsif( lc $cmd eq lc "logFileGetHistoricData" )
  {
    my $value = "";
    my $requestFromTimestamp_UTC = "";

    $value = $args[0]
      if(@args == 1);

    if(lc $value eq lc "stop")
    {
      GroheOndusSmartDevice_Blue_GetData_Stop($hash);
    }
    else
    {
      my $getHistoricDataStartDate_UTC = GroheOndusSmartDevice_GetUTCFromLTZ($hash->{helper}{LogFileGetDataStartDate_LTZ});
      my $applianceInstallationDate_UTC = GroheOndusSmartDevice_GetUTCFromLUTC(ReadingsVal($name, "ApplianceInstallationDate", undef));
      
      if($value eq "")
      {
        if(defined($getHistoricDataStartDate_UTC))
        {
          $requestFromTimestamp_UTC = $getHistoricDataStartDate_UTC;
        }
        elsif(defined($applianceInstallationDate_UTC))
        {
          $requestFromTimestamp_UTC = $applianceInstallationDate_UTC;
        }
      }
      else
      {
        # try to parse $value to timestamp
        my $timestampLocal_s = str2time($value);

        if(not defined($timestampLocal_s))
        {
          return "illegal format";
        }

        my @t = localtime($timestampLocal_s);
        $requestFromTimestamp_UTC = sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
        
        # limit to applianceInstallationDate
        if(defined($applianceInstallationDate_UTC) and
          $requestFromTimestamp_UTC lt $applianceInstallationDate_UTC)
        {
          $requestFromTimestamp_UTC = $applianceInstallationDate_UTC;
        }
      }

      if(defined($requestFromTimestamp_UTC) and
        $requestFromTimestamp_UTC ne "")
      {
        GroheOndusSmartDevice_Blue_GetData_StartCampain($hash, $requestFromTimestamp_UTC);
      }
    }

    return;
  }
  ### Command "logFileCreateFileLogDevice"
  elsif( lc $cmd eq lc "logFileCreateFileLogDevice" )
  {
    my $logFileName = "";
    
    return "usage: $cmd [<devicename>]"
      if( @args > 1 );
    
    $logFileName = ($args[0] =~ tr/ //ds)         # trim whitespaces
      if( @args == 1 );
    
    GroheOndusSmartDevice_FileLog_Create_FileLogDevice($hash, $logFileName);
    
    return;
  }
  ### Command "debugRefreshValues"
  elsif( lc $cmd eq lc "debugRefreshValues" )
  {
    GroheOndusSmartDevice_Blue_GetData_Last($hash);
    return;
  }
  ### Command "debugRefreshState"
  elsif( lc $cmd eq lc "debugRefreshState" )
  {
    GroheOndusSmartDevice_Blue_GetState($hash);
    return;
  }
  ### Command "debugRefreshConfig"
  elsif( lc $cmd eq lc "debugRefreshConfig" )
  {
    GroheOndusSmartDevice_Blue_GetConfig($hash);
    return;
  }
  ### Command "debugOverrideCheckTDT"
  elsif( lc $cmd eq lc "debugOverrideCheckTDT" )
  {
    $hash->{helper}{OverrideCheckTDT} = join( " ", @args );
    GroheOndusSmartDevice_UpdateInternals($hash);
    return;
  }
  ### Command "debugResetProcessedMeasurementTimestamp"
  elsif( lc $cmd eq lc "debugResetProcessedMeasurementTimestamp" )
  {
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    GroheOndusSmartDevice_UpdateInternals($hash);
    return;
  }
  ### Command "debugForceUpdate"
  elsif( lc $cmd eq lc "debugForceUpdate" )
  {
    $hash->{helper}{LastProcessedTimestamp_LUTC}  = "";
    GroheOndusSmartDevice_UpdateInternals($hash);
    
    GroheOndusSmartDevice_TimerExecute($hash);
    return;
  }
  ### unknown Command
  else
  {
    my $list = "";
    
    $list .= "update:noArg ";
    $list .= "clearreadings:noArg ";
    
    $list .= "logFileDelete:noArg "
      if($hash->{helper}{LogFileEnabled} ne "0" and  # check if in logfile mode
      defined($hash->{helper}{LogFileName}) and      # check if filename is defined
      -e $hash->{helper}{LogFileName});              # check if file exists

    my $logFileGetHistoricDataArgs = "";
    if($hash->{helper}{GetSuspendReadings} ne "0")
    {
      $logFileGetHistoricDataArgs = "stop";
    }
    $list .= "logFileGetHistoricData:$logFileGetHistoricDataArgs "
      if($hash->{helper}{LogFileEnabled} ne "0");     # check if in logfile mode

    $list .= "logFileCreateFileLogDevice "
      if($hash->{helper}{LogFileEnabled} ne "0");     # check if in logfile mode

    $list .= "debugRefreshConfig:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugRefreshValues:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugRefreshState:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugOverrideCheckTDT:0,1 "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugResetProcessedMeasurementTimestamp:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    $list .= "debugForceUpdate:noArg "
      if($hash->{helper}{DEBUG} ne "0");

    return "Unknown argument $cmd, choose one of $list";
  }
}

#################################
# GroheOndusSmartDevice_Blue_GetApplianceCommand( $hash, $callbackSuccess, $callbackFail )
sub GroheOndusSmartDevice_Blue_GetApplianceCommand($;$$)
{
  my ( $hash, $callbackSuccess, $callbackFail ) = @_;
  my $name    = $hash->{NAME};

  # definition of the lambda function wich is called to process received data
  my $resultCallback = sub 
  {
    my ( $callbackparam, $data, $errorMsg ) = @_;

    my $stopwatch = gettimeofday();
    $hash->{helper}{Telegram_GetCommandTimeRequest}  = $stopwatch - $callbackparam->{timestampStart};
    $hash->{helper}{Telegram_GetCommandCallback}     = strftime($TimeStampFormat, localtime($stopwatch));
    Log3($name, 4, "GroheOndusSmartDevice_Blue_GetApplianceCommand($name) - resultCallback");

    if( $errorMsg eq "" )
    {
      readingsBeginUpdate($hash);

      if( AttrVal( $name, "debugJSON", 0 ) == 1 )
      {
        readingsBulkUpdate( $hash, "Command_RAW", "\"" . $data . "\"", 1 );
      }

      my $decode_json = eval { decode_json($data) };
    
      if($@)
      {
        Log3($name, 3, "GroheOndusSmartDevice_Blue_GetApplianceCommand($name) - JSON error while request: $@");

        if( AttrVal( $name, "debugJSON", 0 ) == 1 )
        {
          readingsBulkUpdate( $hash, "Appliance_JSON_ERROR", $@, 1 );
        }
        $errorMsg = "GETAPPLIANCECommand_JSON_ERROR";
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
        if(defined( $decode_json->{command} ) and 
          ref( $decode_json->{command} ) eq "HASH" )
        {
          my $measure_now          = $decode_json->{command}->{measure_now};
          my $temp_user_unlock_on  = $decode_json->{command}->{temp_user_unlock_on};
          my $valve_open           = $decode_json->{command}->{valve_open};
          my $buzzer_on            = $decode_json->{command}->{buzzer_on};
          my $buzzer_sound_profile = $decode_json->{command}->{buzzer_sound_profile};

          # update readings
          readingsBulkUpdateIfChanged( $hash, "Cmd_MeasureNow",         "$measure_now" );
          readingsBulkUpdateIfChanged( $hash, "Cmd_TempUserUnlockOn",   "$temp_user_unlock_on" );
          readingsBulkUpdateIfChanged( $hash, "Cmd_ValveOpen",          "$valve_open" );
          readingsBulkUpdateIfChanged( $hash, "Cmd_ValveState",          $valve_open == 1 ? "Open" : "Closed" );
          readingsBulkUpdateIfChanged( $hash, "Cmd_BuzzerOn",           "$buzzer_on" );
          readingsBulkUpdateIfChanged( $hash, "Cmd_BuzzerSoundProfile", "$buzzer_sound_profile" );

          $hash->{helper}{Telegram_GetCommandCounter}++;
        }
        else
        {
          $errorMsg = "UNKNOWN Data";
        }
        readingsEndUpdate( $hash, 1 );
      }
    }

    $hash->{helper}{Telegram_GetCommandTimeProcess}  = gettimeofday() - $stopwatch;

    if( $errorMsg eq "" )
    {
      # if there is a callback then call it
      if( defined($callbackSuccess) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetApplianceCommand($name) - callbackSuccess");
        $callbackSuccess->();
      }
    }
    else
    {
      readingsSingleUpdate( $hash, "state", $errorMsg, 1 );

      # if there is a callback then call it
      if( defined($callbackFail) )
      {
        Log3($name, 4, "GroheOndusSmartDevice_Blue_GetApplianceCommand($name) - callbackFail");
        $callbackFail->();
      }
    }
  }; 

  my $deviceId = $hash->{DEVICEID};
  my $device_locationId = $hash->{ApplianceLocationId};
  my $device_roomId     = $hash->{ApplianceRoomId};

  if( defined( $device_locationId ) and
    defined( $device_roomId ))
  {
    my $param = {};
    $param->{method} = "GET";
    $param->{url} = $hash->{IODev}{URL} . "/iot/locations/" . $device_locationId . "/rooms/" . $device_roomId . "/appliances/" . $deviceId . "/command";
    $param->{header} = "Content-Type: application/json";
    $param->{data} = "{}";
    $param->{httpversion} = "1.0";
    $param->{ignoreredirects} = 0;
    $param->{keepalive} = 1;
      
    $param->{resultCallback} = $resultCallback;
    $param->{timestampStart} = gettimeofday();
    
    $hash->{helper}{Telegram_GetCommandIOWrite}  = strftime($TimeStampFormat, localtime($param->{timestampStart}));

    GroheOndusSmartDevice_IOWrite( $hash, $param );
  }
  else
  {
    # if there is a callback then call it
    if( defined($callbackFail) )
    {
      Log3($name, 4, "GroheOndusSmartDevice_Blue_GetApplianceCommand($name) - callbackFail");
      $callbackFail->();
    }
  }
}
##################################
# GroheOndusSmartDevice_Store
sub GroheOndusSmartDevice_Store($$$$)
{
  my ($hash, $sender, $key, $value) = @_;
  my $type = $hash->{TYPE};
  my $name = $hash->{NAME};

  my $deviceKey = $type . "_" . $name . "_" . $key;

  my $setKeyError = setKeyValue($deviceKey, $value);
  if(defined($setKeyError))
  {
    Log3($name, 3, "$sender($name) - setKeyValue $deviceKey error: $setKeyError");
  }
  else
  {
    Log3($name, 5, "$sender($name) - setKeyValue: $deviceKey -> $value");
  }
}

##################################
# GroheOndusSmartDevice_Restore
sub GroheOndusSmartDevice_Restore($$$$)
{
  my ($hash, $sender, $key, $defaultvalue) = @_;
  my $type = $hash->{TYPE};
  my $name = $hash->{NAME};

  my $deviceKey = $type . "_" . $name . "_" . $key;

  my ($getKeyError, $value) = getKeyValue($deviceKey);
  $value = $defaultvalue
    if(defined($getKeyError) or
      not defined ($value));

  if(defined($getKeyError))
  {
    Log3($name, 3, "$sender($name) - getKeyValue $deviceKey error: $getKeyError");
  }
  else
  {
    Log3($name, 5, "$sender($name) - getKeyValue: $deviceKey -> $value");
  }

  return $value;
}

##################################
# GroheOndusSmartDevice_StoreRename($hash, $sender, $old_name, $key)
sub GroheOndusSmartDevice_StoreRename($$$$)
{
  my ($hash, $sender, $old_name, $key) = @_;
  my $type = $hash->{TYPE};
  my $new_name = $hash->{NAME};

  my $old_deviceKey = $type . "_" . $old_name . "_" . $key;
  my $new_deviceKey = $type . "_" . $new_name . "_" . $key;

  my ($getKeyError, $value) = getKeyValue($old_deviceKey);

  if(defined($getKeyError))
  {
    Log3($new_name, 3, "$sender($new_name) - getKeyValue $old_deviceKey error: $getKeyError");
  }
  else
  {
    Log3($new_name, 5, "$sender($new_name) - getKeyValue: $old_deviceKey -> $value");

    my $setKeyError = setKeyValue($new_deviceKey, $value);
    if(defined($setKeyError))
    {
      Log3($new_name, 3, "$sender($new_name) - setKeyValue $new_deviceKey error: $setKeyError");
    }
    else
    {
      Log3($new_name, 5, "$sender($new_name) - setKeyValue: $new_deviceKey -> $value");
    }
  }

  # delete old key
  setKeyValue($old_deviceKey, undef);
}

##################################
# GroheOndusSmartDevice_GetLTZStringFromLUTC($)
sub GroheOndusSmartDevice_GetLTZStringFromLUTC($)
{
  my ( $timestampUTCString ) = @_;

  if(defined($timestampUTCString) and
    $timestampUTCString ne "")
  {
    # force the timestamp-seconds-string to have a well known length
    # fill with leading zeros
    my $timestamp_LTZ = GroheOndusSmartDevice_GetLTZFromLUTC($timestampUTCString);
    my $timestamp_LTZ_s = time_str2num($timestamp_LTZ);
    my $timestamp_LTZ_s_string = sprintf ("%0${ForcedTimeStampLength}d", $timestamp_LTZ_s);
    return $timestamp_LTZ_s_string;
  }
  else
  {
    return undef;
  }
}


##################################
# GroheOndusSmartDevice_GetLTZFromLUTC($)
sub GroheOndusSmartDevice_GetLTZFromLUTC($)
{
  my ( $timestampUTCString ) = @_;

  if(defined($timestampUTCString) and
    $timestampUTCString ne "")
  {
    my $dataTimestamp_LTZ = substr($timestampUTCString, 0, 19);
    return $dataTimestamp_LTZ;
  }
  else
  {
    return undef;
  }
}

##################################
# GroheOndusSmartDevice_GetUTCFromLUTC($)
sub GroheOndusSmartDevice_GetUTCFromLUTC($)
{
  my ( $timestampUTCString ) = @_;

  if(defined($timestampUTCString) and
    $timestampUTCString ne "")
  {
    my ($ss, $mm, $hh, $day, $month, $year, $zone_s) = strptime($timestampUTCString);
    my $dataTimestamp_SubStr = substr($timestampUTCString, 0, 19);
    my $timestampLocal_s = time_str2num($dataTimestamp_SubStr) - $zone_s;
    my @t = localtime($timestampLocal_s);
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
  }
  else
  {
    return undef;
  }
}

##################################
# GroheOndusSmartDevice_GetUTCFromLTZ()
sub GroheOndusSmartDevice_GetUTCFromLTZ($)
{
  my ( $timestampLTZ ) = @_;

  if(defined($timestampLTZ) and
    $timestampLTZ ne "")
  {
    my $timestampLocal_s = time_str2num($timestampLTZ);
    my @t = gmtime($timestampLocal_s);
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
  }
  else
  {
    return undef;
  }
}

##################################
# GroheOndusSmartDevice_GetUTCMidnightDate()
# This methode returns today"s date convertet to UTC
# returns $gmtMidnightDate
sub GroheOndusSmartDevice_GetUTCMidnightDate($)
{
  my ( $offset_hour ) = @_;

  my $timestamp_LTZ_s = time_str2num(GroheOndusSmartDevice_GetLTZMidnightDate());
  my $currentTimestamp_s = $timestamp_LTZ_s - ($offset_hour * 3600);

  my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) = gmtime($currentTimestamp_s);

  my $gmtMidnightDate = sprintf( "%04d-%02d-%02dT%02d:00:00", $year + 1900, $month + 1, $mday, $hour );

  return $gmtMidnightDate;
}

##################################
# GroheOndusSmartDevice_GetLTZMidnightDate()
sub GroheOndusSmartDevice_GetLTZMidnightDate()
{
  my $currentTimestamp_s = gettimeofday();
  my ( $sec, $min, $hour, $mday, $month, $year, $wday, $yday, $isdst ) = localtime($currentTimestamp_s);

  my $localMidnightDate = sprintf( "%04d-%02d-%02dT%02d:00:00", $year + 1900, $month + 1, $mday, 0 );

  return $localMidnightDate;
}

##################################
# GroheOndusSmartDevice_FileLog_MeasureValueWrite
sub GroheOndusSmartDevice_FileLog_MeasureValueWrite($$$@)
{
  my ( $hash, $title, $timestamp_s, @valueTupleList ) = @_;
  my $name = $hash->{NAME};

  # check if LogFile is enabled
  return
    if($hash->{helper}{LogFileEnabled} ne "1");

  my $filenamePattern = $hash->{helper}{LogFilePattern};
  $filenamePattern = $filenamePattern =~ s/<name>/$name/r; # replace placeholder with $name
  my @t = localtime($timestamp_s);
  my $timestampString = sprintf("%04d-%02d-%02d_%02d:%02d:%02d", $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]);
  
  my $oldLogFileName  = $hash->{helper}{LogFileName};
  my $fileName        = ResolveDateWildcards($filenamePattern, @t);
  my $fileHandle      = undef;

  # filename has changed and new file exists?
  # then open file for (over)write else open it for append
  if(defined($oldLogFileName) and
    $oldLogFileName ne $fileName)
  {
    open($fileHandle, ">", $fileName);
  }
  else
  {
    open($fileHandle, ">>", $fileName);
  }

  my $logfileFormat = $hash->{helper}{LogFileFormat};
  my $measureValueString = ""; 

  if($logfileFormat eq "MeasureValue")
  {
    foreach my $currentData ( @valueTupleList )
    {
      my ($reading, $value ) = @$currentData;

      $value = "undef"
        if(not defined($value));

      $measureValueString .= "$timestampString $name $reading: $value\n";
    }
  }
  else # default: elsif($logfileFormat eq "Measurement")
  {
    $measureValueString .= "$timestampString $name $title:";
    
    foreach my $currentData ( @valueTupleList )
    {
      my ($reading, $value ) = @$currentData;
      
      $value = "undef"
        if(not defined($value));
      
      $measureValueString .=  " $value";
    }
    $measureValueString .= "\n";
  }

  # write data to logfile
  print $fileHandle $measureValueString;
  close($fileHandle);

  if(not defined($hash->{helper}{LogFileName}) or
    $hash->{helper}{LogFileName} ne $fileName)
  {
    $hash->{helper}{LogFileName} = $fileName;
    GroheOndusSmartDevice_UpdateInternals($hash);
  }

  return undef;
}

##################################
# GroheOndusSmartDevice_FileLog_Delete
sub GroheOndusSmartDevice_FileLog_Delete($$)
{
  my ( $hash, $fileName ) = @_;
  my $name = $hash->{NAME};

  # delete file
  my $result = unlink($fileName);

  Log3($name, 4, "GroheOndusSmartDevice_FileLog_Delete($name) - $fileName Result: $result");

  if(-e $fileName) 
  {
    Log3($name, 3, "GroheOndusSmartDevice_FileLog_Delete($name) - $fileName still exists!");
  }
  
  return;
}

##################################
# GroheOndusSmartDevice_FileLog_Create_FileLogDevice
sub GroheOndusSmartDevice_FileLog_Create_FileLogDevice($;$)
{
  my ( $hash, $logFileName ) = @_;
  my $name = $hash->{NAME};
  
  $logFileName = "FileLog_" . $name . "_Data"
    if(not defined($logFileName) or
      $logFileName eq "");         # is empty?
  
  my $filenamePattern = $hash->{helper}{LogFilePattern};
  my $logFilePath = ResolveDateWildcards("%L", localtime());
  $filenamePattern = $filenamePattern =~ s/<name>/$name/r;    # replace placeholder with $name
  $filenamePattern = $filenamePattern =~ s/%L/$logFilePath/r; # replace %L with logfilepath
  
  my $fhemCommand = "defmod $logFileName FileLog $filenamePattern readonly";
  fhem($fhemCommand, 1);

  Log3($name, 4, "GroheOndusSmartDevice_FileLog_Create_FileLogDevice($name) - $fhemCommand");

  # set FileLog device in same room like this
  my $room = AttrVal( $name, "room", "none" );
  if( $room ne "none" )
  {
    CommandAttr( undef, $logFileName . " room " . $room );
  }
}

##################################
# GroheOndusSmartDevice_Getnum
sub GroheOndusSmartDevice_Getnum($)
{
#    use POSIX qw(strtod);
  my ( $str ) = @_;

  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  $! = 0;

  my($num, $unparsed) = strtod($str);

  if(($str eq '') || 
    ($unparsed != 0) || $!) 
  {
    return undef;
  }
  else 
  {
    return $num;
  }
}

##################################
# GroheOndusSmartDevice_PostFn
# This function splits a raw-value string containing a timestamp in seconds and 
# a value with a well known timestamp length in the timestamp and the value and
# puts them into the point structure for a plot 
sub GroheOndusSmartDevice_PostFn($$)
{      
  my($devspec, $array) = @_; 
  
  foreach my $point ( @{$array} ) 
  {
    my $timeStamp_Value = $point->[1]; # take raw-value i.e. "163780529817.3"

    # first 2 numbers are the version information
    my $measurementFormatVersion = $point->[0] = substr($timeStamp_Value, 0, 2);

    # no version information: Format: <10 timetstamp><rest value>
    if($measurementFormatVersion eq "16")
    {
      # first part of the raw-value is the timestamp in seconds (it has a well known length) -> 1637805298
      # second part - the rest - of the raw-value is the value                               -> 17.3
      $point->[0] = substr($timeStamp_Value, 0, 10);
      $point->[1] = substr($timeStamp_Value, 10);
    }
    # with version information:  Format: <2 Version><10 timestamp><rest value>
    elsif($measurementFormatVersion eq "00")
    {
      # first part of the raw-value is the timestamp in seconds (it has a well known length) -> 1637805298
      # second part - the rest - of the raw-value is the value                               -> 17.3
      $point->[0] = substr($timeStamp_Value, 2, 10);
      $point->[1] = substr($timeStamp_Value, 12);
    }
    # default
    else
    {
      # first part of the raw-value is the timestamp in seconds (it has a well known length) -> 1637805298
      # second part - the rest - of the raw-value is the value                               -> 17.3
      $point->[0] = substr($timeStamp_Value, 0, 10);
      $point->[1] = substr($timeStamp_Value, 10);
    }
  }    

  return $array;
}

1;

=pod

=item device
=item summary Module wich represents a Grohe appliance like Sense or SenseGuard

=begin html

<a name="GroheOndusSmartDevice"></a>
<h3>GroheOndusSmartDevice</h3>
<ul>
    In combination with FHEM module <a href="#GroheOndusSmartBridge">GroheOndusSmartBridge</a> this module represents a grohe appliance like <b>Sense</b> or <b>SenseGuard</b>.<br>
    It communicates over <a href="#GroheOndusSmartBridge">GroheOndusSmartBridge</a> to the <b>Grohe-Cloud</b> to get the configuration and measured values of the appliance.<br>
    <br>
    Once the Bridge device is created, the connected devices are recognized and created automatically as GroheOndusSmartDevices in FHEM.<br>
    From now on the appliances can be controlled and the measured values are synchronized with the state and readings of the devices.<br>
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
    <a name="GroheOndusSmartDevice"></a><b>Define</b>
    <ul>
      <code><B>define &lt;name&gt; GroheOndusSmartDevice &lt;bridge&gt; &lt;deviceId&gt; &lt;model&gt;</B></code>
      <br><br>
      Example:<br>
      <ul>
        <code>
        define SenseGuard GroheOndusSmartDevice GroheBridge 00000000-1111-2222-3333-444444444444 sense_guard <br>
        <br>
        </code>
      </ul>
    </ul><br>
    <br>
    <a name="GroheOndusSmartDevicetimestampproblem"></a><b>The Timestamp-Problem</b><br>
    <br>
    The Grohe appliances <b>Sense</b> and <b>SenseGuard</b> send their data to the <b>Grohe-Cloud</b> on a specific period of time.<br>
    <br>
    <ul>
      <li><b>SenseGuard</b> measures every withdrawal and sends the data in a period of <b>15 minutes</b> to the <b>Grohe-Cloud</b></li>
      <li><b>Sense</b> measures once per hour and sends the data in a period of only <b>24 hours</b> to the <b>Grohe-Cloud</b></li>
    </ul>
    <br>
    So, if this module gets new data from the <b>Grohe-Cloud</b> the timestamps of the measurements are lying in the past.<br>
    <br>
    <b>Problem:</b><br>
    When setting the received new data to this module's readings, FHEM's logging-mechanism (<a href="#FileLog">FileLog</a>, <a href="#DbLog">DbLog</a>) will take the current <b>system time</b> - not the timestamps of the measurements - to store the readings' values.<br>
    So plots can't be created the common way with because of the inconsistent timestamp-value-combinations in the logfiles.<br> 
    <br>
    To solve the timestamp-problem this module writes a timestamp-value-combination string to the additional <b>"Measurement"-readings</b> and a plot has to split that string again to get the plot-points.<br>
    See Plot Example below.<br>
    <br>
    Another solution to solve this problem is to enable the <b>LogFile-Mode</b> by setting the attribute <b>logFileModeEnabled</b> to <b>"1"</b>.<br>
    With enabled <b>LogFile-Mode</b> this module is writing new measurevalues additionally to an own logfile with consistent timestamp-value-combinations.<br>
    Define the logfile-name with the attribute <b>logFileNamePattern</b>.<br>
    You can access the logfile in your known way - i.E. from within a plot - by defining a <a href="#FileLog">FileLog</a> device in <b>readonly</b> mode or just set the command <b>logFileCreateFileLogDevice</b>.<br>
    <br>
    With enabled <b>LogFile-Mode</b> you have the possibility to fetch <b>all historic data from the cloud</b> and store it in the logfile(s) by setting the command <b>logFileGetHistoricData</b>.<br>
    <br> 
    <br> 
    <a name="GroheOndusSmartDevice"></a><b>Set</b>
    <ul>
      <li><a name="GroheOndusSmartDeviceupdate">update</a><br>
        Update configuration and values.<br>
        <br>
        <code>
          set &lt;name&gt; update
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceclearreadings">clearreadings</a><br>
        Clear all readings of the module.<br>
        <br>
        <code>
          set &lt;name&gt; clearreadings
        </code>
      </li>
      <br>
      <b><i>SenseGuard-only</i></b><br>
      <br>
      <li><a name="GroheOndusSmartDevicebuzzer">buzzer</a><br>
        <br>
        <code>
          set &lt;name&gt; buzzer &lt;on&gt;|&lt;off&gt;
        </code>
        <br>
        <br>
        <b>on</b> buzzer is turned on.<br>
        <b>off</b> buzzer is turned off.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicevalve">valve</a><br>
        <br>
        <code>
          set &lt;name&gt; valve &lt;on&gt;|&lt;off&gt;
        </code>
        <br>
        <br>
        <b>on</b> open valve.<br>
        <b>off</b> close valve.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceTotalWaterConsumption">TotalWaterConsumption</a><br>
        Adjust the reading <b>TotalWaterConsumption</b> to the given value by setting the attribute <b>offsetTotalWaterConsumption</b>.<br>
        <br>
        <code>
          set &lt;name&gt; TotalWaterConsumption 398086.3
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceTotalHotWaterShare">TotalHotWaterShare</a><br>
        Adjust the reading <b>TotalHotWaterShare</b> to the given value by setting the attribute <b>offsetTotalHotWaterShare</b>.<br>
        <br>
        <code>
          set &lt;name&gt; TotalHotWaterShare 398086.3
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceTotalWaterCost">TotalWaterCost</a><br>
        Adjust the reading <b>TotalWaterCost</b> to the given value by setting the attribute <b>offsetTotalWaterCost</b>.<br>
        <br>
        <code>
          set &lt;name&gt; TotalWaterCost 580.05235
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceTotalEnergyCost">TotalEnergyCost</a><br>
        Adjust the reading <b>TotalEnergyCost</b> to the given value by setting the attribute <b>offsetTotalEnergyCost</b>.<br>
        <br>
        <code>
          set &lt;name&gt; TotalEnergyCost 580.05235
        </code>
      </li>
      <br>
      <b><i>LogFile-Mode</i></b><br>
      <i>If logfile-Mode is enabled (attribute logFileEnabled) all data is additionally written to logfiles(s).</i><br>
      <i>Hint: Set logfile-name pattern with attribute logFilePattern</i><br>
      <br>
      <li><a name="GroheOndusSmartDevicelogFileGetHistoricData">logFileGetHistoricData</a><br>
        <br>
        <code>
          set &lt;name&gt; logFileGetHistoricData [&lt;startdate&gt;|&lt;stop&gt;]
        </code>
        <br>
        <br>
        If parameter <b>startdate</b> is set then start getting all historic data since <b>startdate</b>.<br>
        <br>
        Format is: <b>2021-11-20</b> or <b>2021-11-20T05:42:34</b><br>
        <br>
        Else start getting all historic data since the greater value of the reading <b>ApplianceInstallationDate</b> or the value of attribute <b>logFileGetDataStartDate</b> if set.<br>
        <br>
        If getting historic values is running then the command <b>stop</b> will break that.<br>
        <br>
        Consider setting attribute <b>logFileEnabled</b> to <b>1</b> before start getting historic values to save the values in data-logfiles.<br> 
        <br>
        <i>Hint: you can create a matching <b>readonly</b>-mode <b>FileLog</b> device by setting command <b>logFileCreateFileLogDevice</b>.</i><br>
        <br>
        <b>Attention:<br>
        All former data-logfiles will be cleared and filled with the new values!</b><br>
        <br>
        <b>Attention:<br>
        Depending on the start date this may produce a lot of data and last very long!</b><br>
        <br>
        <br>
        Because of the huge amount of data a SenseGuard device fetches the measurements and withdrawals of only one day per telegram.<br>
        A Sense device fetches the data of 30 days per telegram.
        <br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicelogFileDelete">logFileDelete</a><br>
        <i>only visible if current logfile exists</i><br>
        Remove the current logfile.<br>
        <br>
        <code>
          set &lt;name&gt; logFileDelete
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicelogFileCreateFileLogDevice">logFileCreateFileLogDevice</a><br>
        Create a new <b>readonly</b>-mode <b>FileLog</b> device  in fhem matching this module's <b>logFilePattern</b>.<br>
        <br>
        <code>
          set &lt;name&gt; logFileCreateFileLogDevice [&lt;fileLogName&gt;]
        </code>
        <br>
        <br>
        Parameter [&lt;fileLogName&gt;] is optionally - if empty <b>FileLog_&lt;name&gt;_Data</b> is used
      </li>
      <br>
      <b><i>Debug-mode</i></b><br>
      <br>
      <li><a name="GroheOndusSmartDevicedebugRefreshConfig">debugRefreshConfig</a><br>
        Update the configuration.<br>
        <br>
        <code>
          set &lt;name&gt; debugRefreshConfig
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugRefreshValues">debugRefreshValues</a><br>
        Update the values.<br>
        <br>
        <code>
          set &lt;name&gt; debugRefreshValues
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugRefreshState">debugRefreshState</a><br>
        Update the state.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugGetApplianceCommand">debugGetApplianceCommand</a><br>
        <i>SenseGuard only</i><br>
        Update the command-state.<br>
        <br>
        <code>
          set &lt;name&gt; debugGetApplianceCommand
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugForceUpdate">debugForceUpdate</a><br>
        Forced update of last measurements (includes debugOverrideCheckTDT and debugResetProcessedMeasurementTimestamp).<br>
        <br>
        <code>
          set &lt;name&gt; debugForceUpdate
        </code>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugOverrideCheckTDT">debugOverrideCheckTDT</a><br>
        <br>
        <code>
          set &lt;name&gt; debugOverrideCheckTDT
        </code>
        <br>
        <br>
        If <b>0</b> (default) TDT check is done<br>
        If <b>1</b> no TDT check is done so poll data each configured interval<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugResetProcessedMeasurementTimestamp">debugResetProcessedMeasurementTimestamp</a><br>
        Reset ProcessedMeasurementTimestamp to force complete update of measurements.<br>
        <br>
        <code>
          set &lt;name&gt; debugResetProcessedMeasurementTimestamp
        </code>
      </li>
    </ul>
    <br>
    <a name="GroheOndusSmartDeviceattr"></a><b>Attributes</b><br>
    <ul>
      <li><a name="GroheOndusSmartDeviceinterval">interval</a><br>
        Interval in seconds to poll for locations, rooms and appliances.
        The default value is 60 seconds for SenseGuard and 600 seconds for Sense.
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedisable">disable</a><br>
        If <b>0</b> (default) then GroheOndusSmartDevice is <b>enabled</b>.<br>
        If <b>1</b> then GroheOndusSmartDevice is <b>disabled</b> - no communication to the grohe cloud will be done.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebug">debug</a><br>
        If <b>0</b> (default) debugging mode is <b>disabled</b>.<br>
        If <b>1</b> debugging mode is <b>enabled</b> - more internals and commands are shown.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicedebugJSON">debugJSON</a><br>
        If <b>0</b> (default)<br>
        If <b>1</b> if communication fails the json-payload of incoming telegrams is set to a reading.<br>
      </li>
      <br>
      <b><i>LogFile-Mode</i></b><br>
      <i>Additional internals are shown</i><br>
      <br>
      <li><a name="GroheOndusSmartDevicelogFileEnabled">logFileEnabled</a><br>
        If <b>0</b> (default) no own logfile is written<br>
        If <b>1</b> measurement data is additionally written to own logfile<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicelogFilePattern">logFilePattern</a><br>
        Pattern to generate filename of the own logfile.<br>
        <br>
        Default: <b>%L/&lt;name&gt;-Data-%Y-%m.log</b><br>
        <br>
        The &lt;name&gt;-wildcard is replaced by the modules name.<br>
        The pattern string may contain %-wildcards of the POSIX strftime function of the underlying OS (see your strftime manual). Common used wildcards are:<br>
        <ul>
          <li>%d day of month (01..31)</li>
          <li>%m month (01..12)</li>
          <li>%Y year (1970...)</li>
          <li>%w day of week (0..6); 0 represents Sunday</li>
          <li>%j day of year (001..366)</li>
          <li>%U week number of year with Sunday as first day of week (00..53)</li>
          <li>%W week number of year with Monday as first day of week (00..53)</li>
        </ul><br>
        FHEM also replaces %L by the value of the global logdir attribute.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicelogFileFormat">logFileFormat</a><br>
        Format of the data writen to the logfile.<br>
        <ul>
          <li>
            <b>Measurement</b> (Default) - each measurement is written with all it's measurevalues to one line<br>  
            Format: <b>&lt;timestamp&gt; &lt;devicename&gt; Measurement: &lt;measurevalue_1&gt; &lt;measurevalue_2&gt; .. &lt;measurevalue_n&gt;</b>
          </li>
          <li>
            <b>MeasureValue</b> - each measurevalue is written to a seperate line<br>
            Format: <b>&lt;timestamp&gt; &lt;devicename&gt; &lt;readingname&gt;: &lt;value&gt;</b>
          </li>
        </ul><br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDevicelogFileGetDataStartDate">logFileGetDataStartDate</a><br>
        Set the local start date for the command <b>logFileGetHistoricData</b><br>
        If this attribute is deleted or not set then <b>ApplianceInstallationDate</b> is used for start date.<br>
        <br>
        Format is: <b>2021-11-20</b> or <b>2021-11-20T05:42:34</b><br>
      </li>
      <br>
      <b><i>SenseGuard-only</i></b><br>
      <i>Only visible for SenseGuard appliance</i><br>
      <br>
      <li><a name="GroheOndusSmartDeviceoffsetTotalEnergyCost">offsetTotalEnergyCost</a><br>
        Offset value for calculating reading TotalEnergyCost.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceoffsetTotalWaterCost">offsetTotalWaterCost</a><br>
        Offset value for calculating reading TotalWaterCost.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceoffsetTotalWaterConsumption">offsetTotalWaterConsumption</a><br>
        Offset value for calculating reading TotalWaterConsumption.<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceoffsetTotalHotWaterShare">offsetTotalHotWaterShare</a><br>
        Offset value for calculating reading TotalHotWaterShare.<br>
      </li>
    </ul><br>
    <br>
    <a name="GroheOndusSmartDevicereadings"></a><b>Readings</b><br>
    <ul>
      <li><a name="GroheOndusSmartDeviceMeasurementDataTimestamp">MeasurementDataTimestamp</a><br>
        Example: 001637985182 2021-11-27T04:53:26.000+01:00<br>
        This reading's value consists of two parts: format version and timestamp in seconds and human readable timestamp in utc format<br>
        <b>00</b> first two chars are the format version information<br>
        <b>1637985182</b> the following ten chars are the timestamp in seconds<br>
        space as delimiter<br>
        <b>2021-11-27T04:53:26.000+01:00</b> timestamp in utc format<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceMeasurementHumidity">MeasurementHumidity</a><br>
        Example: 00163798518248<br>
        This reading's value contains a number that consists of version, timestamp in seconds and value<br>
        <b>00</b> first two chars are the format version information<br>
        <b>1637985182</b> following ten chars are the timestamp in seconds<br>
        <b>48</b> the rest is the measurement value<br>
      </li>
      <br>
      <li><a name="GroheOndusSmartDeviceMeasurementTemperature">MeasurementTemperature</a><br>
        Example: 00163798518216.9<br>
        This reading's value contains a number that consists of version, timestamp in seconds and value<br>
        <b>00</b> first two chars are the format version information<br>
        <b>1637985182</b> following ten chars are the timestamp in seconds<br>
        <b>16.9</b> the rest is the measurement value<br>
      </li>
    </ul><br>
    <br>
    <a name="GroheOndusSmartDeviceexample"></a><b>Plot Example</b><br>
    <br>
    Here is an example of a <b>gplotfile</b> using the included postFn <b>GroheOndusSmartDevice_PostFn</b> to split the data of the readings MeasurementTemperature and MeasurementHumidity.<br>
    To use this gplotfile you have to define a <b><a href="https://wiki.fhem.de/wiki/LogProxy">logProxy</a></b> device.<br>
    <br>
    Just replace <b>FileLog_KG_Heizraum_Sense</b> with your <b><a href="https://wiki.fhem.de/wiki/FileLog">FileLog</a></b> device containing the Data of the readings MeasurementTemperature and MeasurementHumidity.<br>
    <br>
    <code>
      # Created by FHEM/98_SVG.pm, 2021-11-26 09:03:29<br>
      set terminal png transparent size &lt;SIZE&gt; crop<br>
      set output '&lt;OUT&gt;.png'<br>
      set xdata time<br>
      set timefmt "%Y-%m-%d_%H:%M:%S"<br>
      set xlabel " "<br>
      set title '&lt;TL&gt;'<br>
      set ytics<br>
      set y2tics<br>
      set grid<br>
      set ylabel "Humidity"<br>
      set y2label "Temperature"<br>
      set yrange [40:60]<br>
      set y2range [10:20]<br>
      <br>
      #logProxy FileLog:FileLog_KG_Heizraum_Sense,postFn='GroheOndusSmartDevice_PostFn':4:KG_Heizraum_Sense.MeasurementTemperature\x3a::<br>
      #logProxy FileLog:FileLog_KG_Heizraum_Sense,postFn='GroheOndusSmartDevice_PostFn':4:KG_Heizraum_Sense.MeasurementHumidity\x3a::<br>
      <br>
      plot "&lt;IN&gt;" using 1:2 axes x1y2 title 'Temperature' ls l0 lw 1 with lines,\<br>
           "&lt;IN&gt;" using 1:2 axes x1y1 title 'Humidity' ls l2 lw 1 with lines<br>
    </code>
    <br>
    <a name="GroheOndusSmartDevicelogfilemode"></a><b>LogFile-Mode</b><br>
    <br>
    With enabled <b>LogFile-Mode</b> this module is writing new measurevalues additionally to an own logfile with consistent timestamp-value-combinations.<br>
    <br>
    To access the logfile from within FHEM in your known way - i.E. from within a plot - you can create a <a href="#FileLog">FileLog</a> device in <b>readonly</b> mode.<br>
    <br>
    Here is an example:<br>
    <br>
    <code>
      defmod FileLog_EG_Hauswirtschaftsraum_Sense_Data FileLog ./log/EG_Hauswirtschaftsraum_Sense-Data-%Y-%m.log <b>readonly</b><br>
    </code>
</ul>

=end html

=for :application/json;q=META.json 74_GroheOndusSmartDevice.pm
{
  "abstract": "Modul to control GroheOndusSmart Devices",
  "x_lang": {
    "de": {
      "abstract": "Modul zur Steuerung von GroheOndusSmart Ger&aumlten"
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
