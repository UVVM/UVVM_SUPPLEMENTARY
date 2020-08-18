--
--  File Name:         AlertLogPkg.vhd
--  Design Unit Name:  AlertLogPkg
--  Revision:          STANDARD VERSION
--
--  Maintainer:        Jim Lewis      email:  jim@synthworks.com
--  Contributor(s):
--     Jim Lewis      jim@synthworks.com
--     Rob Gaddi      Highland Technology.    Inspired SetAlertLogPrefix / Suffix
--
--
--  Description:
--        Alert handling and log filtering (verbosity control)
--        Alert handling provides a method to count failures, errors, and warnings
--          To accumlate counts, a data structure is created in a shared variable
--          It is of type AlertLogStructPType which is defined in AlertLogBasePkg
--        Log filtering provides verbosity control for logs (display or do not display)
--        AlertLogPkg provides a simplified interface to the shared variable
--
--
--  Developed for:
--        SynthWorks Design Inc.
--        VHDL Training Classes
--        11898 SW 128th Ave.  Tigard, Or  97223
--        http://www.SynthWorks.com
--
--  Revision History:
--    Date      Version    Description
--    01/2015   2015.01    Initial revision
--    03/2015   2015.03    Added:  AlertIfEqual, AlertIfNotEqual, AlertIfDiff, PathTail,
--                         ReportNonZeroAlerts, ReadLogEnables
--    05/2015   2015.06    Added IncAlertCount, AffirmIf
--    07/2015   2016.01    Fixed AlertLogID issue with > 32 IDs
--    02/2016   2016.02    Fixed IsLogEnableType (for PASSED), AffirmIf (to pass AlertLevel)
--                         Created LocalInitialize
--    05/2017   2017.05    AffirmIfEqual, AffirmIfDiff,
--                         GetAffirmCount (deprecates GetAffirmCheckCount), IncAffirmCount (deprecates IncAffirmCheckCount),
--                         IsAlertEnabled (alias), IsLogEnabled (alias)
--    04/2018   2018.04    Fix to PathTail.  Prep to change AlertLogIDType to a type.
--    10/2018   2018.10    Added pragmas to allow alerts, logs, and affirmations in RTL code
--                         Added local variable to mirror top level ErrorCount and display in simulator
--                         Added prefix and suffix
--                         Debug printing with number of errors as prefix
--    01/2020   2020.01    Updated Licenses to Apache
--    05/2020   2020.05    Added internal variables AlertCount (W, E, F) and ErrorCount (integer)  
--                         that hold the error state.   These can be displayed in wave windows
--                         in simulation to track number of errors. 
--                         Calls to std.env.stop now return ErrorCount
--                         Updated calls to check for valid AlertLogIDs
--                         Added affirmation count for each level.
--                           Turn off reporting with SetAlertLogOptions (PrintAffirmations => TRUE) ;
--                         Disabled Alerts now handled in separate bins and reported 
--                         separately.  Turn off reporting with SetAlertLogOptions (PrintDisabledAlerts => TRUE) ;
--
--
--  This file is part of OSVVM.
--  
--  Copyright (c) 2015 - 2020 by SynthWorks Design Inc.  
--  
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--  
--      https://www.apache.org/licenses/LICENSE-2.0
--  
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--  


use std.textio.all ;
use work.OsvvmGlobalPkg.all ;
use work.TranscriptPkg.all ;
use work.TextUtilPkg.all ;

library IEEE ;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;

package AlertLogPkg is

--  type     AlertLogIDType       is range integer'low to integer'high ; -- next revsion
  subtype     AlertLogIDType       is integer ;
  type     AlertLogIDVectorType is array (integer range <>) of AlertLogIDType ;
  type     AlertType        is (FAILURE, ERROR, WARNING) ;  -- NEVER
  subtype  AlertIndexType   is AlertType range FAILURE to WARNING ;
  type     AlertCountType   is array (AlertIndexType) of integer ;
  type     AlertEnableType  is array(AlertIndexType) of boolean ;
  type     LogType          is (ALWAYS, DEBUG, FINAL, INFO, PASSED) ;  -- NEVER  -- See function IsLogEnableType
  subtype  LogIndexType     is LogType range DEBUG to PASSED ;
  type     LogEnableType    is array (LogIndexType) of boolean ;

  constant  ALERTLOG_BASE_ID               : AlertLogIDType := 0 ;  -- Careful as some code may assume this is 0.
  constant  ALERTLOG_DEFAULT_ID            : AlertLogIDType := 1 ;
  constant  ALERT_DEFAULT_ID               : AlertLogIDType := ALERTLOG_DEFAULT_ID ;
  constant  LOG_DEFAULT_ID                 : AlertLogIDType := ALERTLOG_DEFAULT_ID ;
  constant  OSVVM_ALERTLOG_ID              : AlertLogIDType := 2 ;
  constant  OSVVM_SCOREBOARD_ALERTLOG_ID   : AlertLogIDType := OSVVM_ALERTLOG_ID ;
  -- NUM_PREDEFINED_AL_IDS intended to be local, but depends on others
  -- constant  NUM_PREDEFINED_AL_IDS          : AlertLogIDType := OSVVM_SCOREBOARD_ALERTLOG_ID - ALERTLOG_BASE_ID ;  -- Not including base
  constant  ALERTLOG_ID_NOT_FOUND          : AlertLogIDType := -1 ;  -- alternately integer'right
  constant  ALERTLOG_ID_NOT_ASSIGNED       : AlertLogIDType := -1 ;
  constant  MIN_NUM_AL_IDS                 : AlertLogIDType := 32 ; -- Number IDs initially allocated

  alias AlertLogOptionsType is work.OsvvmGlobalPkg.OsvvmOptionsType ;

  ------------------------------------------------------------
  --  Alert always goes to the transcript file
  procedure Alert(
    AlertLogID   : AlertLogIDType ;
    Message      : string ;
    Level        : AlertType := ERROR
  ) ;
  procedure Alert( Message : string ; Level : AlertType := ERROR ) ;

  ------------------------------------------------------------
  procedure IncAlertCount(   -- A silent form of alert
    AlertLogID   : AlertLogIDType ;
    Level        : AlertType := ERROR
  ) ;
  procedure IncAlertCount( Level : AlertType := ERROR ) ;

  ------------------------------------------------------------
  -- Similar to assert, except condition is positive
  procedure AlertIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) ;
  impure function  AlertIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;
  impure function  AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  ------------------------------------------------------------
  -- Direct replacement for assert
  procedure AlertIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) ;
  impure function  AlertIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;
  impure function  AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  ------------------------------------------------------------
  -- overloading for common functionality
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic_vector ;  Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : unsigned ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : signed ;            Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : integer ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : real ;              Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : character ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : string ;            Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ;  L, R : time ;              Message : string ; Level : AlertType := ERROR )  ;

  procedure AlertIfEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfEqual( L, R : time ;             Message : string ; Level : AlertType := ERROR )  ;

  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : signed ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : integer ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : real ;             Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : character ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : string ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ;  L, R : time ;             Message : string ; Level : AlertType := ERROR )  ;

  procedure AlertIfNotEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  ;
  procedure AlertIfNotEqual( L, R : time ;             Message : string ; Level : AlertType := ERROR )  ;

  ------------------------------------------------------------
  -- Simple Diff for file comparisons
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) ;
  procedure AlertIfDiff (Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) ;
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) ;
  procedure AlertIfDiff (file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) ;

  ------------------------------------------------------------
  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure AffirmIf(
  ------------------------------------------------------------
    AlertLogID       : AlertLogIDType ;
    condition        : boolean ;
    ReceivedMessage  : string ;
    ExpectedMessage  : string ;
    Enable           : boolean  := FALSE   -- override internal enable
  ) ;

  procedure AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  impure function AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;
  impure function AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;

  procedure AffirmIf(
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    Enable       : boolean := FALSE -- override internal enable
  ) ;

  procedure AffirmIf(condition : boolean ; Message : string ;  Enable : boolean := FALSE ) ;
  impure function  AffirmIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;
  impure function  AffirmIf( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;

  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;
  impure function  AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean ;

  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) ;
  procedure AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;
  impure function  AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean ;

  ------------------------------------------------------------
  procedure AffirmPassed( AlertLogID : AlertLogIDType ; Message : string ; Enable : boolean := FALSE ) ;
  procedure AffirmPassed( Message : string ; Enable : boolean := FALSE ) ;
  procedure AffirmError( AlertLogID : AlertLogIDType ; Message : string ) ;
  procedure AffirmError( Message : string ) ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE );
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE ) ;

  -- Without AlertLogID
  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfEqual( Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE ) ;

  ------------------------------------------------------------
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfDiff (Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) ;
  procedure AffirmIfDiff (file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) ;

  ------------------------------------------------------------
  procedure SetAlertLogJustify (Enable : boolean := TRUE) ;
  procedure ReportAlerts ( Name : String ; AlertCount : AlertCountType ) ;
  procedure ReportAlerts ( Name : string := OSVVM_STRING_INIT_PARM_DETECT ; AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ; ExternalErrors : AlertCountType := (others => 0) ) ;
  procedure ReportNonZeroAlerts ( Name : string := OSVVM_STRING_INIT_PARM_DETECT ; AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ; ExternalErrors : AlertCountType := (others => 0) ) ;
  procedure ClearAlerts ;
  procedure ClearAlertStopCounts ;
  procedure ClearAlertCounts ;
  function "ABS" (L : AlertCountType) return AlertCountType ;
  function "+" (L, R : AlertCountType) return AlertCountType ;
  function "-" (L, R : AlertCountType) return AlertCountType ;
  function "-" (R : AlertCountType) return AlertCountType ;
  impure function SumAlertCount(AlertCount: AlertCountType) return integer ;
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer ;
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer ;
  impure function GetDisabledAlertCount return AlertCountType ;
  impure function GetDisabledAlertCount return integer ;
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType ;
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return integer ;

  ------------------------------------------------------------
  --  log filtering for verbosity control, optionally has a separate file parameter
  procedure Log(
    AlertLogID   : AlertLogIDType ;
    Message      : string ;
    Level        : LogType := ALWAYS ;
    Enable       : boolean := FALSE    -- override internal enable
  ) ;
  procedure Log( Message : string ; Level : LogType := ALWAYS ; Enable : boolean := FALSE) ;

  ------------------------------------------------------------
  -- Alert Enables
  procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) ;
  procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
  impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean ;
  impure function GetAlertEnable(Level : AlertType) return boolean ;
  alias IsAlertEnabled is GetAlertEnable[AlertLogIDType, AlertType return boolean] ;
  alias IsAlertEnabled is GetAlertEnable[AlertType return boolean] ;

  -- Log Enables
  procedure SetLogEnable(Level : LogType ;  Enable : boolean) ;
  procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
  impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean ;
  impure function GetLogEnable(Level : LogType) return boolean ;
  alias IsLogEnabled is GetLogEnable [AlertLogIDType, LogType return boolean] ;  -- same as GetLogEnable
  alias IsLogEnabled is GetLogEnable [LogType return boolean] ;  -- same as GetLogEnable

  procedure ReportLogEnables ;

  procedure SetAlertLogName(Name : string ) ;
  -- synthesis translate_off
  impure function GetAlertLogName(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return string ;
  -- synthesis translate_on
  procedure DeallocateAlertLogStruct ;
  procedure InitializeAlertLogStruct ;
  impure function FindAlertLogID(Name : string ) return AlertLogIDType ;
  impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType ;
  impure function GetAlertLogID(Name : string ; ParentID : AlertLogIDType := ALERTLOG_BASE_ID ; CreateHierarchy : Boolean := TRUE) return AlertLogIDType ;
  impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType ;
  procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) ;
  procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType) ;
  -- synthesis translate_off
  impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string ;
  -- synthesis translate_on
  procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) ;
  procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType) ;
  -- synthesis translate_off
  impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string ;
  -- synthesis translate_on

  ------------------------------------------------------------
  -- Accessor Methods
  procedure SetGlobalAlertEnable (A : boolean := TRUE) ;
  impure function SetGlobalAlertEnable (A : boolean := TRUE) return boolean ;
  impure function GetGlobalAlertEnable return boolean ;
  procedure IncAffirmCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) ;
  impure function GetAffirmCount return natural ;
  procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) ;
  impure function GetAffirmPassedCount return natural ;

  procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) ;
  procedure SetAlertStopCount(Level : AlertType ;  Count : integer) ;
  impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer ;
  impure function GetAlertStopCount(Level : AlertType) return integer ;

  ------------------------------------------------------------
  procedure SetAlertLogOptions (
    FailOnWarning         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    FailOnDisabledErrors  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    ReportHierarchy       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertErrorCount  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertLevel       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertName        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertTime        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogErrorCount    : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogLevel         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogName          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogTime          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    PrintPassed           : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    PrintAffirmations     : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    PrintDisabledAlerts   : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    AlertPrefix           : string := OSVVM_STRING_INIT_PARM_DETECT ;
    LogPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
    ReportPrefix          : string := OSVVM_STRING_INIT_PARM_DETECT ;
    DoneName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    PassName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    FailName              : string := OSVVM_STRING_INIT_PARM_DETECT
  ) ;

  procedure ReportAlertLogOptions ;


  -- synthesis translate_off

  impure function GetAlertLogFailOnWarning        return AlertLogOptionsType ;
  impure function GetAlertLogFailOnDisabledErrors return AlertLogOptionsType ;
  impure function GetAlertLogReportHierarchy      return AlertLogOptionsType ;
  impure function GetAlertLogFoundReportHier      return boolean ;
  impure function GetAlertLogFoundAlertHier       return boolean ;
  impure function GetAlertLogWriteAlertErrorCount return AlertLogOptionsType ;
  impure function GetAlertLogWriteAlertLevel      return AlertLogOptionsType ;
  impure function GetAlertLogWriteAlertName       return AlertLogOptionsType ;
  impure function GetAlertLogWriteAlertTime       return AlertLogOptionsType ;
  impure function GetAlertLogWriteLogErrorCount   return AlertLogOptionsType ;
  impure function GetAlertLogWriteLogLevel        return AlertLogOptionsType ;
  impure function GetAlertLogWriteLogName         return AlertLogOptionsType ;
  impure function GetAlertLogWriteLogTime         return AlertLogOptionsType ;
  impure function GetAlertLogPrintPassed          return AlertLogOptionsType ;
  impure function GetAlertLogPrintAffirmations    return AlertLogOptionsType ;
  impure function GetAlertLogPrintDisabledAlerts  return AlertLogOptionsType ;
  
  impure function GetAlertLogAlertPrefix          return string ;
  impure function GetAlertLogLogPrefix            return string ;

  impure function GetAlertLogReportPrefix         return string ;
  impure function GetAlertLogDoneName             return string ;
  impure function GetAlertLogPassName             return string ;
  impure function GetAlertLogFailName             return string ;

  -- File Reading Utilities
  function IsLogEnableType (Name : String) return boolean ;
  procedure ReadLogEnables (file AlertLogInitFile : text) ;
  procedure ReadLogEnables (FileName : string) ;

  -- String Helper Functions -- This should be in a more general string package
  function PathTail (A : string) return string ;


  -- synthesis translate_on


  --  ------------------------------------------------------------
  -- Deprecated
  --

  -- deprecated
  procedure AlertIf( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR )  ;
  impure function  AlertIf( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  -- deprecated
  procedure AlertIfNot( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR )  ;
  impure function  AlertIfNot( condition : boolean ; AlertLogID : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean ;

  -- deprecated
  procedure AffirmIf(
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    LogLevel     : LogType  ;  -- := PASSED
    AlertLevel   : AlertType := ERROR
  )  ;
  procedure AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; AlertLevel : AlertType ) ;
  procedure AffirmIf(condition : boolean ; Message : string ;  LogLevel : LogType  ; AlertLevel : AlertType := ERROR) ;
  procedure AffirmIf(condition : boolean ; Message : string ;  AlertLevel : AlertType ) ;

  alias IncAffirmCheckCount is IncAffirmCount [AlertLogIDType] ;
  alias GetAffirmCheckCount is GetAffirmCount [return natural] ;
  alias IsLoggingEnabled is GetLogEnable [AlertLogIDType, LogType return boolean] ;  -- same as IsLogEnabled
  alias IsLoggingEnabled is GetLogEnable [LogType return boolean] ;  -- same as IsLogEnabled


end AlertLogPkg ;

--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

use work.NamePkg.all ;

package body AlertLogPkg is

-- synthesis translate_off

  -- instead of justify(to_upper(to_string())), just look up the upper case, left justified values
  type     AlertNameType is array(AlertType) of string(1 to 7) ;
  constant ALERT_NAME : AlertNameType := (WARNING => "WARNING", ERROR => "ERROR  ", FAILURE => "FAILURE") ;  -- , NEVER => "NEVER  "
  type     LogNameType is array(LogType) of string(1 to 7) ;
  constant LOG_NAME : LogNameType := (DEBUG => "DEBUG  ", FINAL => "FINAL  ", INFO => "INFO   ", ALWAYS => "ALWAYS ", PASSED => "PASSED ") ; -- , NEVER => "NEVER  "

  ------------------------------------------------------------
  -- Package Local
  function LeftJustify(A : String;  Amount : integer) return string is
  ------------------------------------------------------------
    constant Spaces : string(1 to  maximum(1, Amount)) := (others => ' ') ;
  begin
    if A'length >= Amount then
      return A ;
    else
      return A & Spaces(1 to Amount - A'length) ;
    end if ;
  end function LeftJustify ;


  type AlertLogStructPType is protected

    ------------------------------------------------------------
    procedure alert (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      message      : string ;
      level        : AlertType := ERROR
    ) ;

    ------------------------------------------------------------
    procedure IncAlertCount ( AlertLogID : AlertLogIDType ; level : AlertType := ERROR ) ;
    procedure SetJustify (Enable : boolean := TRUE) ;
    procedure ReportAlerts ( Name : string ; AlertCount : AlertCountType ) ;
    procedure ReportAlerts ( Name : string := OSVVM_STRING_INIT_PARM_DETECT ; AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ; ExternalErrors : AlertCountType := (0,0,0) ; ReportAll : boolean := TRUE ) ;
    procedure ClearAlerts ;
    procedure ClearAlertStopCounts ;
    impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
    impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType ;
    impure function GetDisabledAlertCount return AlertCountType ;
    impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType ;

    ------------------------------------------------------------
    procedure log (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Message      : string ;
      Level        : LogType := ALWAYS ;
      Enable       : boolean := FALSE    -- override internal enable
    ) ;

    ------------------------------------------------------------
    -- FILE IO Controls
--    procedure SetTranscriptEnable (A : boolean := TRUE) ;
--    impure function IsTranscriptEnabled return boolean ;
--    procedure MirrorTranscript (A : boolean := TRUE) ;
--    impure function IsTranscriptMirrored return boolean ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- AlertLog Structure Creation and Interaction Methods

    ------------------------------------------------------------
    procedure SetAlertLogName(Name : string ) ;
    procedure SetNumAlertLogIDs (NewNumAlertLogIDs : AlertLogIDType) ;
    impure function FindAlertLogID(Name : string ) return AlertLogIDType ;
    impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType ;
    impure function GetAlertLogID(Name : string ; ParentID : AlertLogIDType ; CreateHierarchy : Boolean) return AlertLogIDType ;
    impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType ;
    procedure Initialize(NewNumAlertLogIDs : AlertLogIDType := MIN_NUM_AL_IDS) ;
    procedure Deallocate ;
    procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) ;
    procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType) ;
    impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string ;
    procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) ;
    procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType) ;
    impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- Accessor Methods
    ------------------------------------------------------------
    procedure SetGlobalAlertEnable (A : boolean := TRUE) ;
    impure function GetAlertLogName(AlertLogID : AlertLogIDType) return string ;
    impure function GetGlobalAlertEnable return boolean ;
    procedure IncAffirmCount(AlertLogID : AlertLogIDType) ;
    impure function GetAffirmCount return natural ;
    procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType) ;
    impure function GetAffirmPassedCount return natural ;

    procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) ;
    impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer ;

    procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) ;
    procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
    impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean ;

    procedure SetLogEnable(Level : LogType ;  Enable : boolean) ;
    procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) ;
    impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean ;

    procedure ReportLogEnables ;

    ------------------------------------------------------------
    -- Reporting Accessor
    procedure SetAlertLogOptions (
      FailOnWarning         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      FailOnDisabledErrors  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      ReportHierarchy       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertErrorCount  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertLevel       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertName        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertTime        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogErrorCount    : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogLevel         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogName          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogTime          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      PrintPassed           : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      PrintAffirmations     : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      PrintDisabledAlerts   : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      AlertPrefix           : string := OSVVM_STRING_INIT_PARM_DETECT ;
      LogPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
      ReportPrefix          : string := OSVVM_STRING_INIT_PARM_DETECT ;
      DoneName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName              : string := OSVVM_STRING_INIT_PARM_DETECT
    ) ;
    procedure ReportAlertLogOptions ;

    impure function GetAlertLogFailOnWarning        return AlertLogOptionsType ;
    impure function GetAlertLogFailOnDisabledErrors return AlertLogOptionsType ;
    impure function GetAlertLogReportHierarchy      return AlertLogOptionsType ;
    impure function GetAlertLogFoundReportHier      return boolean ;
    impure function GetAlertLogFoundAlertHier       return boolean ;
    impure function GetAlertLogWriteAlertErrorCount return AlertLogOptionsType ;
    impure function GetAlertLogWriteAlertLevel      return AlertLogOptionsType ;
    impure function GetAlertLogWriteAlertName       return AlertLogOptionsType ;
    impure function GetAlertLogWriteAlertTime       return AlertLogOptionsType ;
    impure function GetAlertLogWriteLogErrorCount   return AlertLogOptionsType ;
    impure function GetAlertLogWriteLogLevel        return AlertLogOptionsType ;
    impure function GetAlertLogWriteLogName         return AlertLogOptionsType ;
    impure function GetAlertLogWriteLogTime         return AlertLogOptionsType ;
    impure function GetAlertLogPrintPassed          return AlertLogOptionsType ;
    impure function GetAlertLogPrintAffirmations    return AlertLogOptionsType ;
    impure function GetAlertLogPrintDisabledAlerts  return AlertLogOptionsType ;

    impure function GetAlertLogAlertPrefix          return string ;
    impure function GetAlertLogLogPrefix            return string ;

    impure function GetAlertLogReportPrefix return string ;
    impure function GetAlertLogDoneName return string ;
    impure function GetAlertLogPassName return string ;
    impure function GetAlertLogFailName return string ;

  end  protected AlertLogStructPType ;

  --- ///////////////////////////////////////////////////////////////////////////

  type AlertLogStructPType is protected body

    variable GlobalAlertEnabledVar     : boolean := TRUE ; -- Allows turn off and on

    variable AffirmCheckCountVar       : natural := 0 ;
    variable PassedCountVar            : natural := 0 ;

    variable ErrorCount : integer := 0 ;
    variable AlertCount : AlertCountType := (0, 0, 0) ;

    ------------------------------------------------------------
    type AlertLogRecType is record
    ------------------------------------------------------------
      Name                : Line ;
      Prefix              : Line ;
      Suffix              : Line ;
      ParentID            : AlertLogIDType ;
      AlertCount          : AlertCountType ;
      DisabledAlertCount  : AlertCountType ;
      AffirmCount         : Integer ; 
      PassedCount         : Integer ; 
      AlertStopCount      : AlertCountType ;
      AlertEnabled        : AlertEnableType ;
      LogEnabled          : LogEnableType ;
    end record AlertLogRecType ;

    ------------------------------------------------------------
    -- Basis for AlertLog Data Structure
    variable NumAlertLogIDsVar          : AlertLogIDType := 0 ; -- defined by initialize
    variable NumAllocatedAlertLogIDsVar : AlertLogIDType := 0 ;

    type AlertLogRecPtrType   is access AlertLogRecType ;
    type AlertLogArrayType    is array (AlertLogIDType range <>) of AlertLogRecPtrType ;
    type AlertLogArrayPtrType is access AlertLogArrayType ;
    variable AlertLogPtr  : AlertLogArrayPtrType ;

    ------------------------------------------------------------
    -- Report formatting settings, with defaults
    variable PrintPassedVar            : boolean := TRUE ; 
    variable PrintAffirmationsVar      : boolean := FALSE ; 
    variable PrintDisabledAlertsVar    : boolean := FALSE ; 

    variable FailOnWarningVar          : boolean := TRUE ;
    variable FailOnDisabledErrorsVar   : boolean := TRUE ;
    variable ReportHierarchyVar        : boolean := TRUE ;
    variable FoundReportHierVar        : boolean := FALSE ;
    variable FoundAlertHierVar         : boolean := FALSE ;

    variable WriteAlertErrorCountVar   : boolean := FALSE ;
    variable WriteAlertLevelVar        : boolean := TRUE ;
    variable WriteAlertNameVar         : boolean := TRUE ;
    variable WriteAlertTimeVar         : boolean := TRUE ;
    variable WriteLogErrorCountVar     : boolean := FALSE ;
    variable WriteLogLevelVar          : boolean := TRUE ;
    variable WriteLogNameVar           : boolean := TRUE ;
    variable WriteLogTimeVar           : boolean := TRUE ;

    variable AlertPrefixVar            : NamePType ;
    variable LogPrefixVar              : NamePType ;
    variable ReportPrefixVar           : NamePType ;
    variable DoneNameVar               : NamePType ;
    variable PassNameVar               : NamePType ;
    variable FailNameVar               : NamePType ;

    variable AlertLogJustifyAmountVar  : integer := 0 ;
    variable ReportJustifyAmountVar    : integer := 0 ;

    ------------------------------------------------------------
    -- PT Local
    impure function VerifyID(
      AlertLogID : AlertLogIDType ;
      LOWEST_ID  : AlertLogIDType := ALERTLOG_BASE_ID
    ) return AlertLogIDType is
    ------------------------------------------------------------
    begin
      if AlertLogID < LOWEST_ID or AlertLogID > NumAlertLogIDsVar then
        Alert(ALERTLOG_BASE_ID, "Invalid AlertLogID") ;
        return ALERTLOG_BASE_ID ;
      else
        return AlertLogID ;
      end if ;
    end function VerifyID ;
    
    ------------------------------------------------------------
    procedure IncAffirmCount(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        AlertLogPtr(localAlertLogID).AffirmCount := AlertLogPtr(localAlertLogID).AffirmCount + 1 ;
        AffirmCheckCountVar := AffirmCheckCountVar + 1 ;
      end if ;
    end procedure IncAffirmCount ;
    
    ------------------------------------------------------------
    impure function GetAffirmCount return natural is
    ------------------------------------------------------------
    begin
      return AffirmCheckCountVar ;
    end function GetAffirmCount ;

    ------------------------------------------------------------
    procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        AlertLogPtr(localAlertLogID).PassedCount := AlertLogPtr(localAlertLogID).PassedCount + 1 ;
        PassedCountVar := PassedCountVar + 1 ;
        AlertLogPtr(localAlertLogID).AffirmCount := AlertLogPtr(localAlertLogID).AffirmCount + 1 ;
        AffirmCheckCountVar := AffirmCheckCountVar + 1 ;
      end if ;
    end procedure IncAffirmPassedCount ;

    ------------------------------------------------------------
    impure function GetAffirmPassedCount return natural is
    ------------------------------------------------------------
    begin
      return PassedCountVar ;
    end function GetAffirmPassedCount ;

    ------------------------------------------------------------
    -- PT Local
    procedure IncrementAlertCount(
    ------------------------------------------------------------
      constant AlertLogID     : in    AlertLogIDType ;
      constant Level          : in    AlertType ;
      variable StopDueToCount : inout boolean
    ) is
    begin
      if AlertLogPtr(AlertLogID).AlertEnabled(Level) then
        AlertLogPtr(AlertLogID).AlertCount(Level) := AlertLogPtr(AlertLogID).AlertCount(Level) + 1 ;
        -- Exceeded Stop Count at this level?
        if AlertLogPtr(AlertLogID).AlertCount(Level) >= AlertLogPtr(AlertLogID).AlertStopCount(Level) then
          StopDueToCount := TRUE ;
        end if ;
        -- Propagate counts to parent(s)  -- Ascend Hierarchy
        if AlertLogID /= ALERTLOG_BASE_ID then
          IncrementAlertCount(AlertLogPtr(AlertLogID).ParentID, Level, StopDueToCount) ;
        end if ;
      else
        -- Disabled, increment disabled count
        AlertLogPtr(AlertLogID).DisabledAlertCount(Level) := AlertLogPtr(AlertLogID).DisabledAlertCount(Level) + 1 ;
      end if ;
    end procedure IncrementAlertCount ;

    ------------------------------------------------------------
    procedure alert (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      message      : string ;
      level        : AlertType := ERROR
    ) is
      variable buf : Line ;
      constant AlertPrefix : string := AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) ;
      variable StopDueToCount : boolean := FALSE ;
      variable localAlertLogID : AlertLogIDType ;
    begin
      -- Only write and count when GlobalAlertEnabledVar is enabled
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
         -- Write when Alert is Enabled
        if AlertLogPtr(localAlertLogID).AlertEnabled(Level) then
          -- Print  %% Alert (nominally)
          write(buf, AlertPrefix) ;
          -- Debug Mode
          if WriteAlertErrorCountVar then
            write(buf, ' ' & justify(to_string(ErrorCount + 1), RIGHT, 2));
          end if ;
          -- Level Name, when enabled (default)
          if WriteAlertLevelVar then
            write(buf, " " & ALERT_NAME(Level)) ; -- uses constant lookup
          end if ;
          -- AlertLog Name
          if FoundAlertHierVar and WriteAlertNameVar then
            write(buf, " in " & LeftJustify(AlertLogPtr(localAlertLogID).Name.all & ",", AlertLogJustifyAmountVar) ) ;
          end if ;
          -- Prefix
          if AlertLogPtr(localAlertLogID).Prefix /= NULL then
            write(buf, ' ' & AlertLogPtr(localAlertLogID).Prefix.all) ;
          end if ;
          -- Message
          write(buf, " " & Message) ;
          -- Suffix
          if AlertLogPtr(localAlertLogID).Suffix /= NULL then
            write(buf, ' ' & AlertLogPtr(localAlertLogID).Suffix.all) ;
          end if ;
          -- Time
          if WriteAlertTimeVar then
             write(buf, " at " & to_string(NOW, 1 ns)) ;
          end if ;
          writeline(buf) ;
        end if ;
        -- Always Count
        IncrementAlertCount(localAlertLogID, Level, StopDueToCount) ;
        AlertCount := AlertLogPtr(ALERTLOG_BASE_ID).AlertCount;
        ErrorCount := SumAlertCount(AlertCount);
        if StopDueToCount then
          write(buf, LF & AlertPrefix & " Stop Count on " & ALERT_NAME(Level) & " reached") ;
          if FoundAlertHierVar then
            write(buf, " in " & AlertLogPtr(localAlertLogID).Name.all) ;
          end if ;
          write(buf, " at " & to_string(NOW, 1 ns) & " ") ;
          writeline(buf) ;
          ReportAlerts(ReportAll => TRUE) ;
          std.env.stop(ErrorCount) ;
        end if ;
      end if ;
    end procedure alert ;

    ------------------------------------------------------------
    procedure IncAlertCount (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      level        : AlertType := ERROR
    ) is
      variable buf : Line ;
      constant AlertPrefix : string := AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) ;
      variable StopDueToCount : boolean := FALSE ;
      variable localAlertLogID : AlertLogIDType ;
    begin
      if GlobalAlertEnabledVar then
        localAlertLogID := VerifyID(AlertLogID) ;
        IncrementAlertCount(localAlertLogID, Level, StopDueToCount) ;
        AlertCount := AlertLogPtr(ALERTLOG_BASE_ID).AlertCount;
        ErrorCount := SumAlertCount(AlertCount);
        if StopDueToCount then
          write(buf, LF & AlertPrefix & " Stop Count on " & ALERT_NAME(Level) & " reached") ;
          if FoundAlertHierVar then
            write(buf, " in " & AlertLogPtr(localAlertLogID).Name.all) ;
          end if ;
          write(buf, " at " & to_string(NOW, 1 ns) & " ") ;
          writeline(buf) ;
          ReportAlerts(ReportAll => TRUE) ;
          std.env.stop(ErrorCount) ;
        end if ;
      end if ;
    end procedure IncAlertCount ;

    ------------------------------------------------------------
    -- PT Local
    impure function CalcJustify (AlertLogID : AlertLogIDType ; CurrentLength : integer ; IndentAmount : integer) return integer_vector is
    ------------------------------------------------------------
      variable ResultValues, LowerLevelValues : integer_vector(1 to 2) ;  -- 1 = Max, 2 = Indented
    begin
      ResultValues(1) := CurrentLength + 1 ;            -- AlertLogJustifyAmountVar
      ResultValues(2) := CurrentLength + IndentAmount ; -- ReportJustifyAmountVar
      for i in AlertLogID+1 to NumAlertLogIDsVar loop
        if AlertLogID = AlertLogPtr(i).ParentID then
          LowerLevelValues := CalcJustify(i, AlertLogPtr(i).Name'length, IndentAmount + 2) ;
          ResultValues(1)  := maximum(ResultValues(1), LowerLevelValues(1)) ;
          ResultValues(2)  := maximum(ResultValues(2), LowerLevelValues(2)) ;
        end if ;
      end loop ;
      return ResultValues ;
    end function CalcJustify ;

    ------------------------------------------------------------
    procedure SetJustify (Enable : boolean := TRUE) is
    ------------------------------------------------------------
      variable ResultValues : integer_vector(1 to 2) ;  -- 1 = Max, 2 = Indented
    begin
      if Enable then 
        ResultValues := CalcJustify(ALERTLOG_BASE_ID, 0, 0) ;
        AlertLogJustifyAmountVar := ResultValues(1) ;
        ReportJustifyAmountVar   := ResultValues(2) ;
      else
        AlertLogJustifyAmountVar := 0 ;
        ReportJustifyAmountVar   := 0 ;
      end if; 
    end procedure SetJustify ;

    ------------------------------------------------------------
    impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertCount ;
    end function GetAlertCount ;

    ------------------------------------------------------------
    impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
      variable Count : AlertCountType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Count := AlertLogPtr(localAlertLogID).AlertCount ;
      if not FailOnWarningVar then
        Count(WARNING) := 0 ;
      end if ;
      return Count ;
    end function GetEnabledAlertCount ;


    ------------------------------------------------------------
    impure function GetDisabledAlertCount return AlertCountType is
    ------------------------------------------------------------
      variable Count : AlertCountType := (others => 0) ;
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        Count := Count + AlertLogPtr(i).DisabledAlertCount ;
--? Should excluded warnings get counted as disabled errors?
--?        if not FailOnWarningVar then
--?          Count(WARNING) := Count(WARNING) + AlertLogPtr(i).AlertCount(WARNING) ;
--?        end if ;
      end loop ;
      return Count ;
    end function GetDisabledAlertCount ;


    ------------------------------------------------------------
    impure function LocalGetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
    ------------------------------------------------------------
      variable Count : AlertCountType ;
      variable localAlertLogID : AlertLogIDType ;
    begin
      Count := AlertLogPtr(AlertLogID).DisabledAlertCount ;
      -- Find Children of this ID
      for i in AlertLogID+1 to NumAlertLogIDsVar loop
        if AlertLogID = AlertLogPtr(i).ParentID then
          Count := Count + LocalGetDisabledAlertCount(i) ; -- Recursively descend into children
--? Should excluded warnings get counted as disabled errors?
--?          if not FailOnWarningVar then
--?            Count(WARNING) := Count(WARNING) + AlertLogPtr(i).AlertCount(WARNING) ;
--?          end if ;
        end if ;
      end loop ;
      return Count ;
    end function LocalGetDisabledAlertCount ;

    ------------------------------------------------------------
    impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return LocalGetDisabledAlertCount(localAlertLogID) ;
    end function GetDisabledAlertCount ;

    ------------------------------------------------------------
    -- PT Local
    procedure PrintTopAlerts (
    ------------------------------------------------------------
      NumErrors          : integer ;
      AlertCount         : AlertCountType ;
      Name               : string ;
      NumDisabledErrors  : integer ;
      DisabledAlertCount : AlertCountType
    ) is
      constant ReportPrefix    : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) ;
      constant DoneName        : string := ResolveOsvvmDoneName(DoneNameVar.GetOpt     ) ;
      constant PassName        : string := ResolveOsvvmPassName(PassNameVar.GetOpt     ) ;
      constant FailName        : string := ResolveOsvvmFailName(FailNameVar.GetOpt     ) ;
      variable buf : line ;
      variable TestFailed : boolean ;
      variable TestErrors : integer := NumErrors ; 
    begin
      TestFailed := (NumErrors /= 0) or ((NumDisabledErrors /= 0) and FailOnDisabledErrorsVar) ;
      if not TestFailed then
        write(buf, ReportPrefix & DoneName & "  " & PassName & "  " & Name) ; -- PASSED
      else
        write(buf, ReportPrefix & DoneName & "  " & FailName & "  " & Name) ; -- FAILED
        if FailOnDisabledErrorsVar then
          TestErrors := TestErrors + NumDisabledErrors ; 
        end if ; 
        write(buf, "  Total Error(s) = " & to_string(TestErrors) ) ;
        write(buf, "  Failures: "        & to_string(AlertCount(FAILURE)) ) ;
        write(buf, "  Errors: "          & to_string(AlertCount(ERROR) ) ) ;
        write(buf, "  Warnings: "        & to_string(AlertCount(WARNING) ) ) ;
      end if ;
      if NumDisabledErrors /= 0 or PrintDisabledAlertsVar then   -- print if exist or enabled
          write(buf, "   Total Disabled Error(s) = " & to_string(NumDisabledErrors)) ;
      end if ; 
      if (NumDisabledErrors /= 0 and FailOnDisabledErrorsVar) or PrintDisabledAlertsVar then  -- print if enabled
        write(buf, "  Failures: "  & to_string(DisabledAlertCount(FAILURE)) ) ;
        write(buf, "  Errors: "    & to_string(DisabledAlertCount(ERROR) ) ) ;
        write(buf, "  Warnings: "  & to_string(DisabledAlertCount(WARNING) ) ) ;
      end if ; 
      if PrintPassedVar or (AffirmCheckCountVar /= 0) or PrintAffirmationsVar then -- Print if passed or printing affirmations
        write(buf, "  Passed: " & to_string(PassedCountVar)) ;
      end if; 
      if (AffirmCheckCountVar /= 0) or PrintAffirmationsVar then
        write(buf, "  Affirmations Checked: " & to_string(AffirmCheckCountVar)) ;
      end if ;
      write(buf, "  at "  & to_string(NOW, 1 ns)) ;
      WriteLine(buf) ;
    end procedure PrintTopAlerts ;

    ------------------------------------------------------------
    -- PT Local
    procedure PrintChild(
    ------------------------------------------------------------
      AlertLogID        : AlertLogIDType ;
      Prefix            : string ;
      IndentAmount      : integer ;
      ReportAll         : boolean ;
      NumDisabledErrors : integer 
    ) is
      variable buf : line ;
    begin
      for i in AlertLogID+1 to NumAlertLogIDsVar loop
        if AlertLogID = AlertLogPtr(i).ParentID then
          if ReportAll or (SumAlertCount(AlertLogPtr(i).AlertCount) > 0) or
              (FailOnDisabledErrorsVar and (SumAlertCount(AlertLogPtr(i).DisabledAlertCount) > 0))
          then
            write(buf, Prefix &  " "   & LeftJustify(AlertLogPtr(i).Name.all, ReportJustifyAmountVar - IndentAmount)) ;
            write(buf, "  Failures: "  & to_string(AlertLogPtr(i).AlertCount(FAILURE) ) ) ;
            write(buf, "  Errors: "    & to_string(AlertLogPtr(i).AlertCount(ERROR) ) ) ;
            write(buf, "  Warnings: "  & to_string(AlertLogPtr(i).AlertCount(WARNING) ) ) ;
            if (NumDisabledErrors /= 0 and FailOnDisabledErrorsVar) or PrintDisabledAlertsVar then
              write(buf, "  Disabled Failures: "  & to_string(AlertLogPtr(i).DisabledAlertCount(FAILURE) ) ) ;
              write(buf, "  Errors: "    & to_string(AlertLogPtr(i).DisabledAlertCount(ERROR) ) ) ;
              write(buf, "  Warnings: "  & to_string(AlertLogPtr(i).DisabledAlertCount(WARNING) ) ) ;
            end if ; 
            if PrintPassedVar then 
              write(buf, "  Passed: " & to_string(AlertLogPtr(i).PassedCount)) ;
            end if; 
            if PrintAffirmationsVar then
              write(buf, "  Affirmations: "  & to_string(AlertLogPtr(i).AffirmCount ) ) ;
            end if ; 
            WriteLine(buf) ;
          end if ;
          PrintChild(
            AlertLogID    => i,
            Prefix        => Prefix & "  ",
            IndentAmount  => IndentAmount + 2,
            ReportAll     => ReportAll,
            NumDisabledErrors  => NumDisabledErrors
          ) ;
        end if ;
      end loop ;
    end procedure PrintChild ;

    ------------------------------------------------------------
    procedure ReportAlerts ( 
      Name           : string := OSVVM_STRING_INIT_PARM_DETECT ; 
      AlertLogID     : AlertLogIDType := ALERTLOG_BASE_ID ; 
      ExternalErrors : AlertCountType := (0,0,0) ; 
      ReportAll      : boolean := TRUE
    ) is
    ------------------------------------------------------------
      variable NumErrors : integer ;
      variable NumDisabledErrors : integer ;
      constant ReportPrefix : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) ;
      variable TurnedOnJustify : boolean := FALSE ;
      variable localAlertLogID : AlertLogIDType ;
      variable DisabledAlertCount : AlertCountType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      if ReportJustifyAmountVar <= 0 then
        TurnedOnJustify := TRUE ; 
        SetJustify ;
      end if ;
      NumErrors := SumAlertCount(  ExternalErrors + GetEnabledAlertCount(localAlertLogID)) ;
      DisabledAlertCount := GetDisabledAlertCount(localAlertLogID) ;
      NumDisabledErrors  := SumAlertCount( DisabledAlertCount ) ;
--old      if FailOnDisabledErrorsVar then
--old        DisabledAlertCount := GetDisabledAlertCount(localAlertLogID) ;
--old        NumDisabledErrors  := SumAlertCount( DisabledAlertCount ) ;
--old      else
--old        NumDisabledErrors  := 0 ;
--old        DisabledAlertCount := (0,0,0) ;
--old      end if ;
      if IsOsvvmStringSet(Name) then
        PrintTopAlerts (
          -- Does not include warnings if they are not counted as an error
          NumErrors          => NumErrors,
          -- Includes warnings, whether they cound as an error or not
          AlertCount         => AlertLogPtr(localAlertLogID).AlertCount + ExternalErrors,
          Name               => Name,
          NumDisabledErrors  => NumDisabledErrors,
          DisabledAlertCount => DisabledAlertCount 
        ) ;
      else
        PrintTopAlerts (
          -- Does not include warnings if they are not counted as an error
          NumErrors          => NumErrors,
          -- Includes warnings, whether they cound as an error or not
          AlertCount         => AlertLogPtr(localAlertLogID).AlertCount + ExternalErrors,
          Name               => AlertLogPtr(localAlertLogID).Name.all,
          NumDisabledErrors  => NumDisabledErrors,
          DisabledAlertCount => DisabledAlertCount 
        ) ;
      end if ;
      --Print Hierarchy when enabled and error or disabled error
      if (FoundReportHierVar and ReportHierarchyVar) and (NumErrors /= 0 or (NumDisabledErrors /=0 and FailOnDisabledErrorsVar)) then
        PrintChild(
          AlertLogID    => localAlertLogID,
          Prefix        => ReportPrefix & "  ",
          IndentAmount  => 2,
          ReportAll     => ReportAll,
          NumDisabledErrors  => NumDisabledErrors
        ) ;
      end if ;
      if TurnedOnJustify then
        -- Turn it back off
        SetJustify(FALSE) ;
      end if ;
    end procedure ReportAlerts ;

    ------------------------------------------------------------
    procedure ReportAlerts ( Name : string ; AlertCount : AlertCountType ) is
    ------------------------------------------------------------
      constant ReportPrefix    : string := ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt ) ;
      constant DoneName        : string := ResolveOsvvmDoneName(DoneNameVar.GetOpt     ) ;
      constant PassName        : string := ResolveOsvvmPassName(PassNameVar.GetOpt     ) ;
      constant FailName        : string := ResolveOsvvmFailName(FailNameVar.GetOpt     ) ;
      variable buf : line ;
      variable NumErrors : integer ; 
    begin
      NumErrors := SumAlertCount(AlertCount) ;
      if  NumErrors = 0 then
        -- Passed
        write(buf, ReportPrefix & DoneName & "  " & PassName & "  " & Name) ;
        write(buf, "  at "  & to_string(NOW, 1 ns)) ;
        WriteLine(buf) ;

      else
        -- Failed
        write(buf, ReportPrefix & DoneName & "  " & FailName & "  "& Name) ;
        write(buf, "  Total Error(s) = "      & to_string(NumErrors) ) ;
        write(buf, "  Failures: "  & to_string(AlertCount(FAILURE)) ) ;
        write(buf, "  Errors: "    & to_string(AlertCount(ERROR) ) ) ;
        write(buf, "  Warnings: "  & to_string(AlertCount(WARNING) ) ) ;
        write(buf, "  at "  & to_string(NOW, 1 ns)) ;
        writeLine(buf) ;
      end if ;
    end procedure ReportAlerts ;

    ------------------------------------------------------------
    procedure ClearAlerts is
    ------------------------------------------------------------
    begin
      AffirmCheckCountVar  := 0 ;
      PassedCountVar       := 0 ;
      AlertCount           := (0, 0, 0) ;
      ErrorCount           := 0 ;

      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        AlertLogPtr(i).AlertCount           := (0, 0, 0) ;
        AlertLogPtr(i).DisabledAlertCount   := (0, 0, 0) ;
        AlertLogPtr(i).AffirmCount          := 0 ;
        AlertLogPtr(i).PassedCount          := 0 ;
      end loop ;
    end procedure ClearAlerts ;
    
    ------------------------------------------------------------
    procedure ClearAlertStopCounts is
    ------------------------------------------------------------
    begin
      AlertLogPtr(ALERTLOG_BASE_ID).AlertStopCount := (FAILURE => 0, ERROR => integer'right, WARNING => integer'right) ;

      for i in ALERTLOG_BASE_ID + 1 to NumAlertLogIDsVar loop
        AlertLogPtr(i).AlertStopCount := (FAILURE => integer'right, ERROR => integer'right, WARNING => integer'right) ;
      end loop ;
    end procedure ClearAlertStopCounts ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalLog (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Message      : string ;
      Level        : LogType
    ) is
      variable buf : line ;
      constant LogPrefix : string := LogPrefixVar.Get(OSVVM_DEFAULT_LOG_PREFIX) ;
    begin
      -- Print  %% log (nominally)
      write(buf, LogPrefix) ;
      -- Debug Mode
      if WriteLogErrorCountVar then
          if WriteAlertErrorCountVar then
            if ErrorCount > 0 then
              write(buf, ' ' & justify(to_string(ErrorCount), RIGHT, 2)) ;
            else
              swrite(buf, "   ") ;
            end if ; 
          end if ;
      end if ;
      -- Level Name, when enabled (default)
      if WriteLogLevelVar then
        write(buf, " " & LOG_NAME(Level) ) ;
      end if ;
      -- AlertLog Name
      if FoundAlertHierVar and WriteLogNameVar then
        write(buf, " in " & LeftJustify(AlertLogPtr(AlertLogID).Name.all & ",", AlertLogJustifyAmountVar) ) ;
      end if ;
      -- Prefix
      if AlertLogPtr(AlertLogID).Prefix /= NULL then
        write(buf, ' ' & AlertLogPtr(AlertLogID).Prefix.all) ;
      end if ;
      -- Message
      write(buf, " " & Message) ;
      -- Suffix
      if AlertLogPtr(AlertLogID).Suffix /= NULL then
        write(buf, ' ' & AlertLogPtr(AlertLogID).Suffix.all) ;
      end if ;
      -- Time
      if WriteLogTimeVar then
         write(buf, " at " & to_string(NOW, 1 ns)) ;
      end if ;
      writeline(buf) ;
    end procedure LocalLog ;

    ------------------------------------------------------------
    procedure log (
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Message      : string ;
      Level        : LogType := ALWAYS ;
      Enable       : boolean := FALSE    -- override internal enable
    ) is
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      if Level = ALWAYS or Enable then
        LocalLog(localAlertLogID, Message, Level) ;
      elsif AlertLogPtr(localAlertLogID).LogEnabled(Level) then
        LocalLog(localAlertLogID, Message, Level) ;
      end if ;
      if Level = PASSED then 
        IncAffirmPassedCount(AlertLogID) ;  -- count the passed and affirmation
      end if ;
    end procedure log ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- AlertLog Structure Creation and Interaction Methods

    ------------------------------------------------------------
    procedure SetAlertLogName(Name : string ) is
    ------------------------------------------------------------
    begin
      Deallocate(AlertLogPtr(ALERTLOG_BASE_ID).Name) ;
      AlertLogPtr(ALERTLOG_BASE_ID).Name := new string'(Name) ;
    end procedure SetAlertLogName ;

    ------------------------------------------------------------
    impure function GetAlertLogName(AlertLogID : AlertLogIDType) return string is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).Name.all ;
    end function GetAlertLogName ;

    ------------------------------------------------------------
    -- PT Local
    procedure NewAlertLogRec(AlertLogID : AlertLogIDType ; Name : string ; ParentID : AlertLogIDType) is
    ------------------------------------------------------------
      variable AlertEnabled   : AlertEnableType ;
      variable AlertStopCount : AlertCountType ;
      variable LogEnabled     : LogEnableType ;
    begin
      if AlertLogID = ALERTLOG_BASE_ID then
        AlertEnabled := (TRUE, TRUE, TRUE) ;
        LogEnabled   := (others => FALSE) ;
        AlertStopCount := (FAILURE => 0, ERROR => integer'right, WARNING => integer'right) ;
      else
        if ParentID < ALERTLOG_BASE_ID then
          AlertEnabled := AlertLogPtr(ALERTLOG_BASE_ID).AlertEnabled ;
          LogEnabled   := AlertLogPtr(ALERTLOG_BASE_ID).LogEnabled ;
        else
          AlertEnabled := AlertLogPtr(ParentID).AlertEnabled ;
          LogEnabled   := AlertLogPtr(ParentID).LogEnabled ;
        end if ;
        AlertStopCount := (FAILURE => integer'right, ERROR => integer'right, WARNING => integer'right) ;
      end if ;
      AlertLogPtr(AlertLogID) := new AlertLogRecType ;
      AlertLogPtr(AlertLogID).Name                := new string'(NAME) ;
      AlertLogPtr(AlertLogID).ParentID            := ParentID ;
      AlertLogPtr(AlertLogID).AlertCount          := (0, 0, 0) ;
      AlertLogPtr(AlertLogID).DisabledAlertCount  := (0, 0, 0) ;
      AlertLogPtr(AlertLogID).AffirmCount         := 0 ;
      AlertLogPtr(AlertLogID).PassedCount         := 0 ;
      AlertLogPtr(AlertLogID).AlertEnabled        := AlertEnabled ;
      AlertLogPtr(AlertLogID).AlertStopCount      := AlertStopCount ;
      AlertLogPtr(AlertLogID).LogEnabled          := LogEnabled ;
    end procedure NewAlertLogRec ;

    ------------------------------------------------------------
    -- PT Local
    -- Construct initial data structure
    procedure LocalInitialize(NewNumAlertLogIDs : AlertLogIDType := MIN_NUM_AL_IDS) is
    ------------------------------------------------------------
    begin
      if NumAllocatedAlertLogIDsVar /= 0 then
        Alert(ALERT_DEFAULT_ID, "AlertLogPkg: Initialize, data structure already initialized", FAILURE) ;
        return ;
      end if ;
      -- Initialize Pointer
      AlertLogPtr := new AlertLogArrayType(ALERTLOG_BASE_ID to ALERTLOG_BASE_ID + NewNumAlertLogIDs) ;
      NumAllocatedAlertLogIDsVar := NewNumAlertLogIDs ;
      -- Create BASE AlertLogID (if it differs from DEFAULT
      if ALERTLOG_BASE_ID /= ALERT_DEFAULT_ID then
        NewAlertLogRec(ALERTLOG_BASE_ID, "AlertLogTop", ALERTLOG_BASE_ID) ;
      end if ;
      -- Create DEFAULT AlertLogID
      NewAlertLogRec(ALERT_DEFAULT_ID, "Default", ALERTLOG_BASE_ID) ;
      NumAlertLogIDsVar := ALERT_DEFAULT_ID ;
      -- Create OSVVM AlertLogID (if it differs from DEFAULT
      if OSVVM_ALERTLOG_ID /= ALERT_DEFAULT_ID then
        NewAlertLogRec(OSVVM_ALERTLOG_ID, "OSVVM", ALERTLOG_BASE_ID) ;
        NumAlertLogIDsVar := NumAlertLogIDsVar + 1 ;
      end if ;
      if OSVVM_SCOREBOARD_ALERTLOG_ID /= OSVVM_ALERTLOG_ID then
        NewAlertLogRec(OSVVM_SCOREBOARD_ALERTLOG_ID, "OSVVM Scoreboard", ALERTLOG_BASE_ID) ;
        NumAlertLogIDsVar := NumAlertLogIDsVar + 1 ;
      end if ;
    end procedure LocalInitialize ;

    ------------------------------------------------------------
    -- Construct initial data structure
    procedure Initialize(NewNumAlertLogIDs : AlertLogIDType := MIN_NUM_AL_IDS) is
    ------------------------------------------------------------
    begin
      LocalInitialize(NewNumAlertLogIDs) ;
    end procedure Initialize ;

    ------------------------------------------------------------
    -- PT Local
    -- Constructs initial data structure using constant below
    impure function LocalInitialize return boolean is
    ------------------------------------------------------------
    begin
      LocalInitialize(MIN_NUM_AL_IDS) ;
      return TRUE ;
    end function LocalInitialize ;

    constant CONSTRUCT_ALERT_DATA_STRUCTURE : boolean := LocalInitialize ;

    ------------------------------------------------------------
    procedure Deallocate is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        Deallocate(AlertLogPtr(i).Name) ;
        Deallocate(AlertLogPtr(i)) ;
      end loop ;
      deallocate(AlertLogPtr) ;
      -- Free up space used by protected types within AlertLogPkg
      AlertPrefixVar.Deallocate ;
      LogPrefixVar.Deallocate ;
      ReportPrefixVar.Deallocate ;
      DoneNameVar.Deallocate ;
      PassNameVar.Deallocate ;
      FailNameVar.Deallocate ;
      -- Restore variables to their initial state
      PrintPassedVar           := TRUE ;
      PrintAffirmationsVar     := FALSE ; 
      PrintDisabledAlertsVar   := FALSE ; 
      NumAlertLogIDsVar           := 0 ;
      NumAllocatedAlertLogIDsVar  := 0 ;
      GlobalAlertEnabledVar    := TRUE ; -- Allows turn off and on
      AffirmCheckCountVar      := 0 ;
      PassedCountVar           := 0 ;
      FailOnWarningVar         := TRUE ;
      FailOnDisabledErrorsVar  := TRUE ;
      ReportHierarchyVar       := TRUE ;
      FoundReportHierVar       := FALSE ;
      FoundAlertHierVar        := FALSE ;
      WriteAlertErrorCountVar  := FALSE ;
      WriteAlertLevelVar       := TRUE ;
      WriteAlertNameVar        := TRUE ;
      WriteAlertTimeVar        := TRUE ;
      WriteLogErrorCountVar    := FALSE ;
      WriteLogLevelVar         := TRUE ;
      WriteLogNameVar          := TRUE ;
      WriteLogTimeVar          := TRUE ;
    end procedure Deallocate ;

    ------------------------------------------------------------
    -- PT Local.
    procedure GrowAlertStructure (NewNumAlertLogIDs : AlertLogIDType) is
    ------------------------------------------------------------
      variable oldAlertLogPtr : AlertLogArrayPtrType ;
    begin
      if NumAllocatedAlertLogIDsVar = 0 then
        Initialize (NewNumAlertLogIDs) ;   -- Construct initial structure
      else
        oldAlertLogPtr := AlertLogPtr ;
        AlertLogPtr := new AlertLogArrayType(ALERTLOG_BASE_ID to NewNumAlertLogIDs) ;
        AlertLogPtr(ALERTLOG_BASE_ID to NumAlertLogIDsVar) := oldAlertLogPtr(ALERTLOG_BASE_ID to NumAlertLogIDsVar) ;
        deallocate(oldAlertLogPtr) ;
      end if ;
      NumAllocatedAlertLogIDsVar := NewNumAlertLogIDs ;
    end procedure GrowAlertStructure ;

    ------------------------------------------------------------
    -- Sets a AlertLogPtr to a particular size
    -- Use for small bins to save space or large bins to
    -- suppress the resize and copy as a CovBin autosizes.
    procedure SetNumAlertLogIDs (NewNumAlertLogIDs : AlertLogIDType) is
    ------------------------------------------------------------
      variable oldAlertLogPtr : AlertLogArrayPtrType ;
    begin
      if NewNumAlertLogIDs > NumAllocatedAlertLogIDsVar then
        GrowAlertStructure(NewNumAlertLogIDs) ;
      end if;
    end procedure SetNumAlertLogIDs ;

    ------------------------------------------------------------
    -- PT Local
    impure function GetNextAlertLogID return AlertLogIDType is
    ------------------------------------------------------------
      variable NewNumAlertLogIDs : AlertLogIDType ;
    begin
      NewNumAlertLogIDs := NumAlertLogIDsVar + 1 ;
      if NewNumAlertLogIDs > NumAllocatedAlertLogIDsVar then
        GrowAlertStructure(NumAllocatedAlertLogIDsVar + MIN_NUM_AL_IDS) ;
      end if ;
      NumAlertLogIDsVar := NewNumAlertLogIDs ;
      return NumAlertLogIDsVar ;
    end function GetNextAlertLogID ;

    ------------------------------------------------------------
    impure function FindAlertLogID(Name : string ) return AlertLogIDType is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        if Name = AlertLogPtr(i).Name.all then
          return i ;
        end if ;
      end loop ;
      return ALERTLOG_ID_NOT_FOUND ; -- not found
    end function FindAlertLogID ;

    ------------------------------------------------------------
    -- PT Local
    impure function LocalFindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType is
    ------------------------------------------------------------
      variable CurParentID : AlertLogIDType ;
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        CurParentID := AlertLogPtr(i).ParentID ;
        if Name = AlertLogPtr(i).Name.all and
          (CurParentID = ParentID or CurParentID = ALERTLOG_ID_NOT_ASSIGNED or ParentID = ALERTLOG_ID_NOT_ASSIGNED)
        then
          return i ;
        end if ;
      end loop ;
      return ALERTLOG_ID_NOT_FOUND ; -- not found
    end function LocalFindAlertLogID ;

    ------------------------------------------------------------
    impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType is
    ------------------------------------------------------------
      variable CurParentID : AlertLogIDType ;
      variable localParentID : AlertLogIDType ;
    begin
      localParentID := VerifyID(ParentID, ALERTLOG_ID_NOT_ASSIGNED) ;
      return LocalFindAlertLogID(Name, localParentID) ;
    end function FindAlertLogID ;

    ------------------------------------------------------------
    impure function GetAlertLogID(Name : string ; ParentID : AlertLogIDType ; CreateHierarchy : Boolean) return AlertLogIDType is
    ------------------------------------------------------------
      variable ResultID : AlertLogIDType ;
      variable localParentID : AlertLogIDType ;
    begin
      localParentID := VerifyID(ParentID, ALERTLOG_ID_NOT_ASSIGNED) ;
      ResultID := LocalFindAlertLogID(Name, localParentID) ;
      if ResultID /= ALERTLOG_ID_NOT_FOUND then
        -- found it, set localParentID
        if AlertLogPtr(ResultID).ParentID = ALERTLOG_ID_NOT_ASSIGNED then
          AlertLogPtr(ResultID).ParentID := localParentID ;
        -- else -- do not update as ParentIDs are either same or input localParentID = ALERTLOG_ID_NOT_ASSIGNED
        end if ;
      else
        -- Create a new ID
        ResultID := GetNextAlertLogID ;
        NewAlertLogRec(ResultID, Name, localParentID) ;
        FoundAlertHierVar := TRUE ;
        if CreateHierarchy then
          FoundReportHierVar := TRUE ;
        end if ;
      end if ;
      return ResultID ;
    end function GetAlertLogID ;

    ------------------------------------------------------------
    impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).ParentID ;
    end function GetAlertLogParentID ;

    ------------------------------------------------------------
    procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Prefix) ;
      if Name'length > 0 then 
        AlertLogPtr(localAlertLogID).Prefix := new string'(Name) ;
      end if ; 
    end procedure SetAlertLogPrefix ;

    ------------------------------------------------------------
    procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Prefix) ;
    end procedure UnSetAlertLogPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).Prefix.all ;
    end function GetAlertLogPrefix ;

    ------------------------------------------------------------
    procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Suffix) ;
      if Name'length > 0 then 
        AlertLogPtr(localAlertLogID).Suffix := new string'(Name) ;
      end if ; 
    end procedure SetAlertLogSuffix ;

    ------------------------------------------------------------
    procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      Deallocate(AlertLogPtr(localAlertLogID).Suffix) ;
    end procedure UnSetAlertLogSuffix ;

    ------------------------------------------------------------
    impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).Suffix.all ;
    end function GetAlertLogSuffix ;

    ------------------------------------------------------------
    ------------------------------------------------------------
    -- Accessor Methods
    ------------------------------------------------------------

    ------------------------------------------------------------
    procedure SetGlobalAlertEnable (A : boolean := TRUE) is
    ------------------------------------------------------------
    begin
      GlobalAlertEnabledVar := A ;
    end procedure SetGlobalAlertEnable ;

    ------------------------------------------------------------
    impure function GetGlobalAlertEnable return boolean is
    ------------------------------------------------------------
    begin
      return GlobalAlertEnabledVar ;
    end function GetGlobalAlertEnable ;

    ------------------------------------------------------------
    -- PT LOCAL
    procedure SetOneStopCount(
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Level        : AlertType ;
      Count        : integer
    ) is
    begin
      if AlertLogPtr(AlertLogID).AlertStopCount(Level) = integer'right then
        AlertLogPtr(AlertLogID).AlertStopCount(Level) := Count ;
      else
        AlertLogPtr(AlertLogID).AlertStopCount(Level) :=
          AlertLogPtr(AlertLogID).AlertStopCount(Level) + Count ;
      end if ;
    end procedure SetOneStopCount ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalSetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
    ------------------------------------------------------------
    begin
      SetOneStopCount(AlertLogID, Level, Count) ;
      if AlertLogID /= ALERTLOG_BASE_ID then
        LocalSetAlertStopCount(AlertLogPtr(AlertLogID).ParentID, Level, Count) ;
      end if ;
    end procedure LocalSetAlertStopCount ;

    ------------------------------------------------------------
    procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      LocalSetAlertStopCount(AlertLogID, Level, Count) ;
    end procedure SetAlertStopCount ;

    ------------------------------------------------------------
    impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertStopCount(Level) ;
    end function GetAlertStopCount ;

    ------------------------------------------------------------
    procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        AlertLogPtr(i).AlertEnabled(Level) := Enable ;
      end loop ;
    end procedure SetAlertEnable ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalSetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
    begin
      AlertLogPtr(AlertLogID).AlertEnabled(Level) := Enable ;
      if DescendHierarchy then
        for i in AlertLogID+1 to NumAlertLogIDsVar loop
          if AlertLogID = AlertLogPtr(i).ParentID then
            LocalSetAlertEnable(i, Level, Enable, DescendHierarchy) ;
          end if ;
        end loop ;
      end if ;
    end procedure LocalSetAlertEnable ;

    ------------------------------------------------------------
    procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      LocalSetAlertEnable(localAlertLogID, Level, Enable, DescendHierarchy) ;
    end procedure SetAlertEnable ;

    ------------------------------------------------------------
    impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      return AlertLogPtr(localAlertLogID).AlertEnabled(Level) ;
    end function GetAlertEnable ;

    ------------------------------------------------------------
    procedure SetLogEnable(Level : LogType ;  Enable : boolean) is
    ------------------------------------------------------------
    begin
      for i in ALERTLOG_BASE_ID to NumAlertLogIDsVar loop
        AlertLogPtr(i).LogEnabled(Level) := Enable ;
      end loop ;
    end procedure SetLogEnable ;

    ------------------------------------------------------------
    -- PT Local
    procedure LocalSetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
    begin
      AlertLogPtr(AlertLogID).LogEnabled(Level) := Enable ;
      if DescendHierarchy then
        for i in AlertLogID+1 to NumAlertLogIDsVar loop
          if AlertLogID = AlertLogPtr(i).ParentID then
            LocalSetLogEnable(i, Level, Enable, DescendHierarchy) ;
          end if ;
        end loop ;
      end if ;
    end procedure LocalSetLogEnable ;

    ------------------------------------------------------------
    procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      LocalSetLogEnable(localAlertLogID, Level, Enable, DescendHierarchy) ;
    end procedure SetLogEnable ;

    ------------------------------------------------------------
    impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean is
    ------------------------------------------------------------
      variable localAlertLogID : AlertLogIDType ;
    begin
      localAlertLogID := VerifyID(AlertLogID) ;
      if Level = ALWAYS then
        return TRUE ;
      else
        return AlertLogPtr(localAlertLogID).LogEnabled(Level) ;
      end if ;
    end function GetLogEnable ;

    ------------------------------------------------------------
    -- PT Local
    procedure PrintLogLevels(
    ------------------------------------------------------------
      AlertLogID   : AlertLogIDType ;
      Prefix       : string ;
      IndentAmount : integer
    ) is
      variable buf : line ;
    begin
      write(buf, Prefix &  " "   & LeftJustify(AlertLogPtr(AlertLogID).Name.all, ReportJustifyAmountVar - IndentAmount)) ;
      for i in LogIndexType loop
        if AlertLogPtr(AlertLogID).LogEnabled(i) then
--          write(buf, " "  & to_string(AlertLogPtr(AlertLogID).LogEnabled(i)) ) ;
          write(buf, " "  & to_string(i)) ;
        end if ;
      end loop ;
      WriteLine(buf) ;
      for i in AlertLogID+1 to NumAlertLogIDsVar loop
        if AlertLogID = AlertLogPtr(i).ParentID then
          PrintLogLevels(
            AlertLogID    => i,
            Prefix        => Prefix & "  ",
            IndentAmount  => IndentAmount + 2
          ) ;
        end if ;
      end loop ;
    end procedure PrintLogLevels ;

    ------------------------------------------------------------
    procedure ReportLogEnables is
    ------------------------------------------------------------
      variable TurnedOnJustify : boolean := FALSE ;
    begin
      if ReportJustifyAmountVar <= 0 then
        TurnedOnJustify := TRUE ; 
        SetJustify ;
      end if ;
      PrintLogLevels(ALERTLOG_BASE_ID, "", 0) ;
      if TurnedOnJustify then
        -- Turn it back off
        SetJustify(FALSE) ;
      end if ;
    end procedure ReportLogEnables ;

    ------------------------------------------------------------
    procedure SetAlertLogOptions (
    ------------------------------------------------------------
      FailOnWarning         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      FailOnDisabledErrors  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      ReportHierarchy       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertErrorCount  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertLevel       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertName        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteAlertTime        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogErrorCount    : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogLevel         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogName          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      WriteLogTime          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      PrintPassed           : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      PrintAffirmations     : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      PrintDisabledAlerts   : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
      AlertPrefix           : string := OSVVM_STRING_INIT_PARM_DETECT ;
      LogPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
      ReportPrefix          : string := OSVVM_STRING_INIT_PARM_DETECT ;
      DoneName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
      PassName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
      FailName              : string := OSVVM_STRING_INIT_PARM_DETECT
    ) is
    begin
      if FailOnWarning /= OPT_INIT_PARM_DETECT then
        FailOnWarningVar := IsEnabled(FailOnWarning) ;
      end if ;
      if FailOnDisabledErrors /= OPT_INIT_PARM_DETECT then
        FailOnDisabledErrorsVar := IsEnabled(FailOnDisabledErrors) ;
      end if ;
      if ReportHierarchy /= OPT_INIT_PARM_DETECT then
        ReportHierarchyVar := IsEnabled(ReportHierarchy) ;
      end if ;
      if WriteAlertErrorCount /= OPT_INIT_PARM_DETECT then
        WriteAlertErrorCountVar := IsEnabled(WriteAlertErrorCount) ;
      end if ;
      if WriteAlertLevel /= OPT_INIT_PARM_DETECT then
        WriteAlertLevelVar := IsEnabled(WriteAlertLevel) ;
      end if ;
      if WriteAlertName /= OPT_INIT_PARM_DETECT then
        WriteAlertNameVar := IsEnabled(WriteAlertName) ;
      end if ;
      if WriteAlertTime /= OPT_INIT_PARM_DETECT then
        WriteAlertTimeVar := IsEnabled(WriteAlertTime) ;
      end if ;
      if WriteLogErrorCount /= OPT_INIT_PARM_DETECT then
        WriteLogErrorCountVar := IsEnabled(WriteLogErrorCount) ;
      end if ;
      if WriteLogLevel /= OPT_INIT_PARM_DETECT then
        WriteLogLevelVar := IsEnabled(WriteLogLevel) ;
      end if ;
      if WriteLogName /= OPT_INIT_PARM_DETECT then
        WriteLogNameVar := IsEnabled(WriteLogName) ;
      end if ;
      if WriteLogTime /= OPT_INIT_PARM_DETECT then
        WriteLogTimeVar := IsEnabled(WriteLogTime) ;
      end if ;
      if PrintPassed /= OPT_INIT_PARM_DETECT then
        PrintPassedVar := IsEnabled(PrintPassed) ;
      end if ;
      if PrintAffirmations /= OPT_INIT_PARM_DETECT then
        PrintAffirmationsVar := IsEnabled(PrintAffirmations) ;
      end if ;
      if PrintDisabledAlerts /= OPT_INIT_PARM_DETECT then
        PrintDisabledAlertsVar := IsEnabled(PrintDisabledAlerts) ;
      end if ;
      if AlertPrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        AlertPrefixVar.Set(AlertPrefix) ;
      end if ;
      if LogPrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        LogPrefixVar.Set(LogPrefix) ;
      end if ;
      if ReportPrefix /= OSVVM_STRING_INIT_PARM_DETECT then
        ReportPrefixVar.Set(ReportPrefix) ;
      end if ;
      if DoneName /= OSVVM_STRING_INIT_PARM_DETECT then
        DoneNameVar.Set(DoneName) ;
      end if ;
      if PassName /= OSVVM_STRING_INIT_PARM_DETECT then
        PassNameVar.Set(PassName) ;
      end if ;
      if FailName /= OSVVM_STRING_INIT_PARM_DETECT then
        FailNameVar.Set(FailName) ;
      end if ;
    end procedure SetAlertLogOptions ;

    ------------------------------------------------------------
    procedure ReportAlertLogOptions is
    ------------------------------------------------------------
      variable buf : line ;
    begin
      -- Boolean Values
      swrite(buf, "ReportAlertLogOptions" & LF ) ;
      swrite(buf, "---------------------" & LF ) ;
      swrite(buf, "FailOnWarningVar:        " & to_string(FailOnWarningVar        ) & LF ) ;
      swrite(buf, "FailOnDisabledErrorsVar: " & to_string(FailOnDisabledErrorsVar ) & LF ) ;
      swrite(buf, "ReportHierarchyVar:      " & to_string(ReportHierarchyVar      ) & LF ) ;
      swrite(buf, "FoundReportHierVar:      " & to_string(FoundReportHierVar      ) & LF ) ; -- Not set by user
      swrite(buf, "FoundAlertHierVar:       " & to_string(FoundAlertHierVar       ) & LF ) ; -- Not set by user
      swrite(buf, "WriteAlertErrorCountVar: " & to_string(WriteAlertErrorCountVar ) & LF ) ;
      swrite(buf, "WriteAlertLevelVar:      " & to_string(WriteAlertLevelVar      ) & LF ) ;
      swrite(buf, "WriteAlertNameVar:       " & to_string(WriteAlertNameVar       ) & LF ) ;
      swrite(buf, "WriteAlertTimeVar:       " & to_string(WriteAlertTimeVar       ) & LF ) ;
      swrite(buf, "WriteLogErrorCountVar:   " & to_string(WriteLogErrorCountVar   ) & LF ) ;
      swrite(buf, "WriteLogLevelVar:        " & to_string(WriteLogLevelVar        ) & LF ) ;
      swrite(buf, "WriteLogNameVar:         " & to_string(WriteLogNameVar         ) & LF ) ;
      swrite(buf, "WriteLogTimeVar:         " & to_string(WriteLogTimeVar         ) & LF ) ;
      swrite(buf, "PrintPassedVar:          " & to_string(PrintPassedVar    ) & LF ) ;  
      swrite(buf, "PrintAffirmationsVar:    " & to_string(PrintAffirmationsVar    ) & LF ) ;  
      swrite(buf, "PrintDisabledAlertsVar:  " & to_string(PrintDisabledAlertsVar  ) & LF ) ; 

      -- String
      swrite(buf, "AlertPrefixVar:          " & string'(AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX))  & LF ) ;
      swrite(buf, "LogPrefixVar:            " & string'(LogPrefixVar.Get(OSVVM_DEFAULT_LOG_PREFIX))      & LF ) ;
      swrite(buf, "ReportPrefixVar:         " & ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) & LF ) ;
      swrite(buf, "DoneNameVar:             " & ResolveOsvvmDoneName(DoneNameVar.GetOpt)        & LF ) ;
      swrite(buf, "PassNameVar:             " & ResolveOsvvmPassName(PassNameVar.GetOpt)        & LF ) ;
      swrite(buf, "FailNameVar:             " & ResolveOsvvmFailName(FailNameVar.GetOpt)        & LF ) ;
      writeline(buf) ;
    end procedure ReportAlertLogOptions ;

    ------------------------------------------------------------
    impure function GetAlertLogFailOnWarning        return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(FailOnWarningVar) ;
    end function GetAlertLogFailOnWarning ;

    ------------------------------------------------------------
    impure function GetAlertLogFailOnDisabledErrors return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(FailOnDisabledErrorsVar) ;
    end function GetAlertLogFailOnDisabledErrors ;

    ------------------------------------------------------------
    impure function GetAlertLogReportHierarchy      return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(ReportHierarchyVar) ;
    end function GetAlertLogReportHierarchy ;

    ------------------------------------------------------------
    impure function GetAlertLogFoundReportHier       return boolean is
    ------------------------------------------------------------
    begin
      return FoundReportHierVar ;
    end function GetAlertLogFoundReportHier ;

    ------------------------------------------------------------
    impure function GetAlertLogFoundAlertHier       return boolean is
    ------------------------------------------------------------
    begin
      return FoundAlertHierVar ;
    end function GetAlertLogFoundAlertHier ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertErrorCount return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertErrorCountVar) ;
    end function GetAlertLogWriteAlertErrorCount ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertLevel      return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertLevelVar) ;
    end function GetAlertLogWriteAlertLevel ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertName       return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertNameVar) ;
    end function GetAlertLogWriteAlertName ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteAlertTime       return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteAlertTimeVar) ;
    end function GetAlertLogWriteAlertTime ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogErrorCount return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogErrorCountVar) ;
    end function GetAlertLogWriteLogErrorCount ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogLevel        return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogLevelVar) ;
    end function GetAlertLogWriteLogLevel ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogName         return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogNameVar) ;
    end function GetAlertLogWriteLogName ;

    ------------------------------------------------------------
    impure function GetAlertLogWriteLogTime         return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(WriteLogTimeVar) ;
    end function GetAlertLogWriteLogTime ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintPassed    return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintPassedVar) ;
    end function GetAlertLogPrintPassed ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintAffirmations    return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintAffirmationsVar) ;
    end function GetAlertLogPrintAffirmations ;

    ------------------------------------------------------------
    impure function GetAlertLogPrintDisabledAlerts  return AlertLogOptionsType is
    ------------------------------------------------------------
    begin
      return to_OsvvmOptionsType(PrintDisabledAlertsVar) ;
    end function GetAlertLogPrintDisabledAlerts ;

    ------------------------------------------------------------
    impure function GetAlertLogAlertPrefix          return string is
    ------------------------------------------------------------
    begin
      return AlertPrefixVar.Get(OSVVM_DEFAULT_ALERT_PREFIX) ;
    end function GetAlertLogAlertPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogLogPrefix            return string is
    ------------------------------------------------------------
    begin
      return LogPrefixVar.Get(OSVVM_DEFAULT_LOG_PREFIX) ;
    end function GetAlertLogLogPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogReportPrefix return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmWritePrefix(ReportPrefixVar.GetOpt) ;
    end function GetAlertLogReportPrefix ;

    ------------------------------------------------------------
    impure function GetAlertLogDoneName return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmDoneName(DoneNameVar.GetOpt) ;
    end function GetAlertLogDoneName ;

    ------------------------------------------------------------
    impure function GetAlertLogPassName return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmPassName(PassNameVar.GetOpt) ;
    end function GetAlertLogPassName ;

    ------------------------------------------------------------
    impure function GetAlertLogFailName return string is
    ------------------------------------------------------------
    begin
      return ResolveOsvvmFailName(FailNameVar.GetOpt) ;
    end function GetAlertLogFailName ;

  end protected body AlertLogStructPType ;



  shared variable AlertLogStruct : AlertLogStructPType ;

-- synthesis translate_on

--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////
--- ///////////////////////////////////////////////////////////////////////////

  ------------------------------------------------------------
  procedure Alert(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    Message      : string  ;
    Level        : AlertType := ERROR
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.Alert(AlertLogID, Message, Level) ;
    -- synthesis translate_on
  end procedure alert ;

  ------------------------------------------------------------
  procedure Alert( Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    -- synthesis translate_on
  end procedure alert ;

  ------------------------------------------------------------
  procedure IncAlertCount(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    Level        : AlertType := ERROR
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAlertCount(AlertLogID, Level) ;
    -- synthesis translate_on
  end procedure IncAlertCount ;

  ------------------------------------------------------------
  procedure IncAlertCount( Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAlertCount(ALERT_DEFAULT_ID, Level) ;
    -- synthesis translate_on
  end procedure IncAlertCount ;


  ------------------------------------------------------------
  procedure AlertIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(AlertLogID , Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIf ;

  ------------------------------------------------------------
  procedure AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID , Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIf ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AlertIf( not ReadValid, failure, "Read Failed") ;
  impure function  AlertIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(AlertLogID , Message, Level) ;
    end if ;
    -- synthesis translate_on
    return condition ;
  end function AlertIf ;

  ------------------------------------------------------------
  impure function  AlertIf( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    end if ;
    -- synthesis translate_on
    return condition ;
  end function AlertIf ;

  ------------------------------------------------------------
  procedure AlertIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(AlertLogID, Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNot ;

  ------------------------------------------------------------
  procedure AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNot ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AlertIfNot( not ReadValid, failure, "Read Failed") ;
  impure function  AlertIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(AlertLogID, Message, Level) ;
    end if ;
    -- synthesis translate_on
    return not condition ;
  end function AlertIfNot ;

  ------------------------------------------------------------
  impure function  AlertIfNot( condition : boolean ; Message : string ; Level : AlertType := ERROR ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if not condition then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message, Level) ;
    end if ;
    -- synthesis translate_on
    return not condition ;
  end function AlertIfNot ;


  ------------------------------------------------------------
  -- AlertIfEqual with AlertLogID
  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( AlertLogID : AlertLogIDType ; L, R : time ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(AlertLogID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;


  ------------------------------------------------------------
  -- AlertIfEqual without AlertLogID
  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;

  ------------------------------------------------------------
  procedure AlertIfEqual( L, R : time ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L = R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L = R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfEqual ;


  ------------------------------------------------------------
  -- AlertIfNotEqual with AlertLogID
  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( AlertLogID : AlertLogIDType ; L, R : time ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(AlertLogID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;


  ------------------------------------------------------------
  -- AlertIfNotEqual without AlertLogID
  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : std_logic ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : std_logic_vector ; Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : unsigned ;         Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : signed ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L ?/= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : integer ;          Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : real ;             Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L, 4) & "   R = " & to_string(R, 4), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : character ;        Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : string ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & L & "   R = " & R, Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;

  ------------------------------------------------------------
  procedure AlertIfNotEqual( L, R : time ;           Message : string ; Level : AlertType := ERROR )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    if L /= R then
      AlertLogStruct.Alert(ALERT_DEFAULT_ID, Message & " L /= R,  L = " & to_string(L) & "   R = " & to_string(R), Level) ;
    end if ;
    -- synthesis translate_on
  end procedure AlertIfNotEqual ;


  ------------------------------------------------------------
  -- Local
  procedure LocalAlertIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string ; Level : AlertType ; Valid : out boolean ) is
  -- Simple diff.
  ------------------------------------------------------------
    variable Buf1, Buf2 : line ;
    variable File1Done, File2Done : boolean ;
    variable LineCount : integer := 0 ;
  begin
    -- synthesis translate_off
    ReadLoop : loop
      File1Done := EndFile(File1) ;
      File2Done := EndFile(File2) ;
      exit ReadLoop when File1Done or File2Done ;

      ReadLine(File1, Buf1) ;
      ReadLine(File2, Buf2) ;
      LineCount := LineCount + 1 ;

      if Buf1.all /= Buf2.all then
        AlertLogStruct.Alert(AlertLogID , Message & " File miscompare on line " & to_string(LineCount), Level) ;
        exit ReadLoop ;
      end if ;
    end loop ReadLoop ;
    if File1Done /= File2Done then
      if not File1Done then
        AlertLogStruct.Alert(AlertLogID , Message & " File1 longer than File2 " & to_string(LineCount), Level) ;
      end if ;
      if not File2Done then
        AlertLogStruct.Alert(AlertLogID , Message & " File2 longer than File1 " & to_string(LineCount), Level) ;
      end if ;
    end if;
    if File1Done and File2Done then
      Valid := TRUE ;
    else
      Valid := FALSE ;
    end if ;
    -- synthesis translate_on
  end procedure LocalAlertIfDiff ;

  ------------------------------------------------------------
  -- Local
  procedure LocalAlertIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string ; Level : AlertType ; Valid : out boolean ) is
  -- Open files and call AlertIfDiff[text, ...]
  ------------------------------------------------------------
    file FileID1, FileID2 : text ;
    variable status1, status2 : file_open_status ;
  begin
    -- synthesis translate_off
    Valid := FALSE ;
    file_open(status1, FileID1, Name1, READ_MODE) ;
    file_open(status2, FileID2, Name2, READ_MODE) ;
    if status1 = OPEN_OK and status2 = OPEN_OK then
      LocalAlertIfDiff (AlertLogID, FileID1, FileID2, Message & " " & Name1 & " /= " & Name2 & ", ", Level, Valid) ;
    else
      if status1 /= OPEN_OK then
        AlertLogStruct.Alert(AlertLogID , Message & " File, " & Name1 & ", did not open", Level) ;
      end if ;
      if status2 /= OPEN_OK then
        AlertLogStruct.Alert(AlertLogID , Message & " File, " & Name2 & ", did not open", Level) ;
      end if ;
    end if;
    -- synthesis translate_on
  end procedure LocalAlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) is
  -- Open files and call AlertIfDiff[text, ...]
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, Name1, Name2, Message, Level, Valid) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (Name1, Name2 : string; Message : string := "" ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (ALERT_DEFAULT_ID, Name1, Name2, Message, Level, Valid) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) is
  -- Simple diff.
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, File1, File2, Message, Level, Valid ) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AlertIfDiff (file File1, File2 : text; Message : string := "" ; Level : AlertType := ERROR ) is
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (ALERT_DEFAULT_ID, File1, File2, Message, Level, Valid ) ;
    -- synthesis translate_on
  end procedure AlertIfDiff ;

  ------------------------------------------------------------
  procedure AffirmIf(
  ------------------------------------------------------------
    AlertLogID       : AlertLogIDType ;
    condition        : boolean ;
    ReceivedMessage  : string ;
    ExpectedMessage  : string ;
    Enable           : boolean  := FALSE   -- override internal enable
  ) is
  begin
    -- synthesis translate_off
    if condition then
      -- PASSED.  Count affirmations and PASSED internal to LOG to catch all of them
      AlertLogStruct.Log(AlertLogID, ReceivedMessage, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      AlertLogStruct.Alert(AlertLogID, ReceivedMessage & ExpectedMessage, ERROR) ;
    end if ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  procedure AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  impure function AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;

  ------------------------------------------------------------
  impure function AffirmIf( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;


  ------------------------------------------------------------
  procedure AffirmIf(
  ------------------------------------------------------------
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    Enable       : boolean  := FALSE   -- override internal enable
  ) is
  begin
    -- synthesis translate_off
    if condition then
      -- PASSED.  Count affirmations and PASSED internal to LOG to catch all of them
      AlertLogStruct.Log(AlertLogID, Message, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      AlertLogStruct.Alert(AlertLogID, Message, ERROR) ;
    end if ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  procedure AffirmIf(condition : boolean ; Message : string ;  Enable : boolean := FALSE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIf;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AffirmIf( ID, not ReadValid, "Read Failed") ;
  impure function  AffirmIf( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, condition, Message, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;

  ------------------------------------------------------------
  impure function  AffirmIf( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, Enable) ;
    -- synthesis translate_on
    return condition ;
  end function AffirmIf ;

  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  procedure AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AffirmIfNot( not ReadValid, failure, "Read Failed") ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;

  ------------------------------------------------------------
  impure function  AffirmIfNot( condition : boolean ; ReceivedMessage, ExpectedMessage : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, ReceivedMessage, ExpectedMessage, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;

  ------------------------------------------------------------
  procedure AffirmIfNot( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  procedure AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfNot ;

  ------------------------------------------------------------
  -- useful in a loop:  exit when AffirmIfNot( not ReadValid, failure, "Read Failed") ;
  impure function  AffirmIfNot( AlertLogID  : AlertLogIDType ; condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, not condition, Message, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;

  ------------------------------------------------------------
  impure function  AffirmIfNot( condition : boolean ; Message : string ; Enable : boolean := FALSE ) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, not condition, Message, Enable) ;
    -- synthesis translate_on
    return not condition ;
  end function AffirmIfNot ;


  ------------------------------------------------------------
  ------------------------------------------------------------
  procedure AffirmPassed( AlertLogID : AlertLogIDType ; Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, TRUE, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmPassed ;

  ------------------------------------------------------------
  procedure AffirmPassed( Message : string ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, TRUE, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmPassed ;

  ------------------------------------------------------------
  procedure AffirmError( AlertLogID : AlertLogIDType ; Message : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, FALSE, Message, FALSE) ;
    -- synthesis translate_on
  end procedure AffirmError ;

  ------------------------------------------------------------
  procedure AffirmError( Message : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, FALSE, Message, FALSE) ;
    -- synthesis translate_on
  end procedure AffirmError ;

  -- With AlertLogID
  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, ??(Received ?= Expected),
      Message & " Received : " & to_string(Received),
      " ?= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, ??(Received ?= Expected),
      Message & " Received : " & to_hstring(Received),
      " ?= Expected : " & to_hstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, ??(Received ?= Expected),
      Message & " Received : " & to_hstring(Received),
      " ?= Expected : " & to_hstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, ??(Received ?= Expected),
      Message & " Received : " & to_hstring(Received),
      " ?= Expected : " & to_hstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received),
      " = Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received, 4),
      " = Expected : " & to_string(Expected, 4),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received),
      " = Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & Received,
      " = Expected : " & Expected,
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( AlertLogID : AlertLogIDType ; Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, Received = Expected,
      Message & " Received : " & to_string(Received),
      " = Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  -- Without AlertLogID
  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : std_logic ;  Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, ??(Received ?= Expected),
      Message & " Received : " & to_string(Received),
      " ?= Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : std_logic_vector ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, ??(Received ?= Expected),
      Message & " Received : " & to_hstring(Received),
      " ?= Expected : " & to_hstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : unsigned ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, ??(Received ?= Expected),
      Message & " Received : " & to_hstring(Received),
      " ?= Expected : " & to_hstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : signed ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, ??(Received ?= Expected),
      Message & " Received : " & to_hstring(Received),
      " ?= Expected : " & to_hstring(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : integer ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received),
      " = Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : real ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received, 4),
      " = Expected : " & to_string(Expected, 4),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : character ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received),
      " = Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : string ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & Received,
      " = Expected : " & Expected,
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfEqual( Received, Expected : time ; Message : string := "" ; Enable : boolean := FALSE )  is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, Received = Expected,
      Message & " Received : " & to_string(Received),
      " = Expected : " & to_string(Expected),
      Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfEqual ;

  ------------------------------------------------------------
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) is
  -- Open files and call AffirmIfDiff[text, ...]
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, Name1, Name2, Message, ERROR, Valid) ;
    if Valid then
      AlertLogStruct.Log(AlertLogID, Message & " " & Name1 & " = " & Name2, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      -- Alert already signaled by LocalAlertIfDiff
    end if ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
  procedure AffirmIfDiff (Name1, Name2 : string; Message : string := "" ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIfDiff(ALERT_DEFAULT_ID, Name1, Name2, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
  procedure AffirmIfDiff (AlertLogID : AlertLogIDType ; file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) is
  -- Simple diff.
  ------------------------------------------------------------
    variable Valid : boolean ;
  begin
    -- synthesis translate_off
    LocalAlertIfDiff (AlertLogID, File1, File2, Message, ERROR, Valid ) ;
    if Valid then
      AlertLogStruct.Log(AlertLogID, Message, PASSED, Enable) ;
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      -- Alert already signaled by LocalAlertIfDiff
    end if ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
  procedure AffirmIfDiff (file File1, File2 : text; Message : string := "" ; Enable : boolean := FALSE ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AffirmIfDiff(ALERT_DEFAULT_ID, File1, File2, Message, Enable) ;
    -- synthesis translate_on
  end procedure AffirmIfDiff ;

  ------------------------------------------------------------
  procedure SetAlertLogJustify (Enable : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetJustify(Enable) ;
    -- synthesis translate_on
  end procedure SetAlertLogJustify ;

  ------------------------------------------------------------
  procedure ReportAlerts ( Name : String ; AlertCount : AlertCountType ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlerts(Name, AlertCount) ;
    -- synthesis translate_on
  end procedure ReportAlerts ;

  ------------------------------------------------------------
  procedure ReportAlerts ( Name : string := OSVVM_STRING_INIT_PARM_DETECT ; AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ; ExternalErrors : AlertCountType := (others => 0) ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlerts(Name, AlertLogID, ExternalErrors, TRUE) ;
    -- synthesis translate_on
  end procedure ReportAlerts ;

  ------------------------------------------------------------
  procedure ReportNonZeroAlerts ( Name : string := OSVVM_STRING_INIT_PARM_DETECT ; AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID ; ExternalErrors : AlertCountType := (others => 0) ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlerts(Name, AlertLogID, ExternalErrors, FALSE) ;
    -- synthesis translate_on
  end procedure ReportNonZeroAlerts ;

  ------------------------------------------------------------
  procedure ClearAlerts is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ClearAlerts ;
    -- synthesis translate_on
  end procedure ClearAlerts ;
  
  ------------------------------------------------------------
  procedure ClearAlertStopCounts is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ClearAlertStopCounts ;
    -- synthesis translate_on
  end procedure ClearAlertStopCounts ;

  ------------------------------------------------------------
  procedure ClearAlertCounts is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ClearAlerts ;
    AlertLogStruct.ClearAlertStopCounts ;
    -- synthesis translate_on
  end procedure ClearAlertCounts ;
  
  ------------------------------------------------------------
  function "ABS" (L : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := ABS( L(FAILURE) ) ;
    Result(ERROR)   := ABS( L(ERROR) ) ;
    Result(WARNING) := ABS( L(WARNING) );
    -- synthesis translate_on
    return Result ;
  end function "ABS" ;

  ------------------------------------------------------------
  function "+" (L, R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := L(FAILURE) + R(FAILURE) ;
    Result(ERROR)   := L(ERROR)   + R(ERROR) ;
    Result(WARNING) := L(WARNING) + R(WARNING) ;
    -- synthesis translate_on
    return Result ;
  end function "+" ;

  ------------------------------------------------------------
  function "-" (L, R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := L(FAILURE) - R(FAILURE) ;
    Result(ERROR)   := L(ERROR)   - R(ERROR) ;
    Result(WARNING) := L(WARNING) - R(WARNING) ;
    -- synthesis translate_on
    return Result ;
  end function "-" ;

  ------------------------------------------------------------
  function "-" (R : AlertCountType) return AlertCountType is
  ------------------------------------------------------------
    variable Result : AlertCountType ;
  begin
    -- synthesis translate_off
    Result(FAILURE) := - R(FAILURE) ;
    Result(ERROR)   := - R(ERROR) ;
    Result(WARNING) := - R(WARNING) ;
    -- synthesis translate_on
    return Result ;
  end function "-" ;

  ------------------------------------------------------------
  impure function SumAlertCount(AlertCount: AlertCountType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    -- Using ABS ensures correct expected error handling.
    result := abs(AlertCount(FAILURE)) + abs(AlertCount(ERROR)) + abs(AlertCount(WARNING)) ;
    -- synthesis translate_on
    return result ;
  end function SumAlertCount ;

  ------------------------------------------------------------
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertCount ;

  ------------------------------------------------------------
  impure function GetAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetAlertCount(AlertLogID)) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertCount ;

  ------------------------------------------------------------
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetEnabledAlertCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetEnabledAlertCount ;

  ------------------------------------------------------------
  impure function GetEnabledAlertCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetEnabledAlertCount(AlertLogID)) ;
    -- synthesis translate_on
    return result ;
  end function GetEnabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetDisabledAlertCount ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetDisabledAlertCount) ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return AlertCountType is
  ------------------------------------------------------------
    variable result : AlertCountType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetDisabledAlertCount(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  impure function GetDisabledAlertCount(AlertLogID: AlertLogIDType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := SumAlertCount(AlertLogStruct.GetDisabledAlertCount(AlertLogID)) ;
    -- synthesis translate_on
    return result ;
  end function GetDisabledAlertCount ;

  ------------------------------------------------------------
  procedure Log(
    AlertLogID   : AlertLogIDType ;
    Message      : string ;
    Level        : LogType := ALWAYS ;
    Enable       : boolean := FALSE    -- override internal enable
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.Log(AlertLogID, Message, Level, Enable) ;
    -- synthesis translate_on
  end procedure log ;

  ------------------------------------------------------------
  procedure Log( Message : string ; Level : LogType := ALWAYS ; Enable : boolean := FALSE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Log(LOG_DEFAULT_ID, Message, Level, Enable) ;
    -- synthesis translate_on
  end procedure log ;

  ------------------------------------------------------------
  procedure SetAlertEnable(Level : AlertType ;  Enable : boolean) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertEnable(Level, Enable) ;
    -- synthesis translate_on
  end procedure SetAlertEnable ;

  ------------------------------------------------------------
  procedure SetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertEnable(AlertLogID, Level, Enable, DescendHierarchy) ;
    -- synthesis translate_on
  end procedure SetAlertEnable ;

  ------------------------------------------------------------
  impure function GetAlertEnable(AlertLogID : AlertLogIDType ;  Level : AlertType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertEnable(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertEnable ;

  ------------------------------------------------------------
  impure function GetAlertEnable(Level : AlertType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertEnable(ALERT_DEFAULT_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertEnable ;

  ------------------------------------------------------------
  procedure SetLogEnable(Level : LogType ;  Enable : boolean) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetLogEnable(Level, Enable) ;
    -- synthesis translate_on
  end procedure SetLogEnable ;

  ------------------------------------------------------------
  procedure SetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType ;  Enable : boolean ; DescendHierarchy : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetLogEnable(AlertLogID, Level, Enable, DescendHierarchy) ;
    -- synthesis translate_on
  end procedure SetLogEnable ;

  ------------------------------------------------------------
  impure function GetLogEnable(AlertLogID : AlertLogIDType ;  Level : LogType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetLogEnable(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetLogEnable ;

  ------------------------------------------------------------
  impure function GetLogEnable(Level : LogType) return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetLogEnable(LOG_DEFAULT_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetLogEnable ;

  ------------------------------------------------------------
  procedure ReportLogEnables is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportLogEnables ;
    -- synthesis translate_on
  end ReportLogEnables ;

 ------------------------------------------------------------
  procedure SetAlertLogName(Name : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogName(Name) ;
    -- synthesis translate_on
  end procedure SetAlertLogName ;

  -- synthesis translate_off
  ------------------------------------------------------------
  impure function GetAlertLogName(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogName(AlertLogID) ;
  end GetAlertLogName ;
  -- synthesis translate_on

  ------------------------------------------------------------
  procedure DeallocateAlertLogStruct is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Deallocate ;
    -- synthesis translate_on
  end procedure DeallocateAlertLogStruct ;

  ------------------------------------------------------------
  procedure InitializeAlertLogStruct is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.Initialize ;
    -- synthesis translate_on
  end procedure InitializeAlertLogStruct ;

  ------------------------------------------------------------
  impure function FindAlertLogID(Name : string ) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.FindAlertLogID(Name) ;
    -- synthesis translate_on
    return result ;
  end function FindAlertLogID ;

  ------------------------------------------------------------
  impure function FindAlertLogID(Name : string ; ParentID : AlertLogIDType) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.FindAlertLogID(Name, ParentID) ;
    -- synthesis translate_on
    return result ;
  end function FindAlertLogID ;

  ------------------------------------------------------------
  impure function GetAlertLogID(Name : string ; ParentID : AlertLogIDType := ALERTLOG_BASE_ID ; CreateHierarchy : Boolean := TRUE) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogID(Name, ParentID, CreateHierarchy ) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogID ;

  ------------------------------------------------------------
  impure function GetAlertLogParentID(AlertLogID : AlertLogIDType) return AlertLogIDType is
  ------------------------------------------------------------
    variable result : AlertLogIDType ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertLogParentID(AlertLogID) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertLogParentID ;

  ------------------------------------------------------------
  procedure SetAlertLogPrefix(AlertLogID : AlertLogIDType; Name : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogPrefix(AlertLogID, Name) ;
    -- synthesis translate_on
  end procedure SetAlertLogPrefix ;

  ------------------------------------------------------------
  procedure UnSetAlertLogPrefix(AlertLogID : AlertLogIDType ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.UnSetAlertLogPrefix(AlertLogID) ;
    -- synthesis translate_on
  end procedure UnSetAlertLogPrefix ;

  -- synthesis translate_off
  ------------------------------------------------------------
  impure function GetAlertLogPrefix(AlertLogID : AlertLogIDType) return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrefix(AlertLogID) ;
  end function GetAlertLogPrefix ;
  -- synthesis translate_on

  ------------------------------------------------------------
  procedure SetAlertLogSuffix(AlertLogID : AlertLogIDType; Name : string ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogSuffix(AlertLogID, Name) ;
    -- synthesis translate_on
  end procedure SetAlertLogSuffix ;

  ------------------------------------------------------------
  procedure UnSetAlertLogSuffix(AlertLogID : AlertLogIDType ) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.UnSetAlertLogSuffix(AlertLogID) ;
    -- synthesis translate_on
  end procedure UnSetAlertLogSuffix ;

  -- synthesis translate_off
  ------------------------------------------------------------
  impure function GetAlertLogSuffix(AlertLogID : AlertLogIDType) return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogSuffix(AlertLogID) ;
  end function GetAlertLogSuffix ;
  -- synthesis translate_on

  ------------------------------------------------------------
  procedure SetGlobalAlertEnable (A : boolean := TRUE) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetGlobalAlertEnable(A) ;
    -- synthesis translate_on
  end procedure SetGlobalAlertEnable ;

  ------------------------------------------------------------
  -- Set using constant.  Set before code runs.
  impure function SetGlobalAlertEnable (A : boolean := TRUE) return boolean is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetGlobalAlertEnable(A) ;
    -- synthesis translate_on
    return A ;
  end function SetGlobalAlertEnable ;

  ------------------------------------------------------------
  impure function GetGlobalAlertEnable return boolean is
  ------------------------------------------------------------
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetGlobalAlertEnable ;
    -- synthesis translate_on
    return result ;
  end function GetGlobalAlertEnable ;

  ------------------------------------------------------------
  procedure IncAffirmCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAffirmCount(AlertLogID) ;
    -- synthesis translate_on
  end procedure IncAffirmCount ;

  ------------------------------------------------------------
  impure function GetAffirmCount return natural is
  ------------------------------------------------------------
    variable result : natural ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAffirmCount ;
    -- synthesis translate_on
    return result ;
  end function GetAffirmCount ;

  ------------------------------------------------------------
  procedure IncAffirmPassedCount(AlertLogID : AlertLogIDType := ALERTLOG_BASE_ID) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.IncAffirmPassedCount(AlertLogID) ;
    -- synthesis translate_on
  end procedure IncAffirmPassedCount ;

  ------------------------------------------------------------
  impure function GetAffirmPassedCount return natural is
  ------------------------------------------------------------
    variable result : natural ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAffirmPassedCount ;
    -- synthesis translate_on
    return result ;
  end function GetAffirmPassedCount ;

  ------------------------------------------------------------
  procedure SetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertStopCount(AlertLogID, Level, Count) ;
    -- synthesis translate_on
  end procedure SetAlertStopCount ;

  ------------------------------------------------------------
  procedure SetAlertStopCount(Level : AlertType ;  Count : integer) is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertStopCount(ALERTLOG_BASE_ID, Level, Count) ;
    -- synthesis translate_on
  end procedure SetAlertStopCount ;

  ------------------------------------------------------------
  impure function GetAlertStopCount(AlertLogID : AlertLogIDType ;  Level : AlertType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertStopCount(AlertLogID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertStopCount ;

  ------------------------------------------------------------
  impure function GetAlertStopCount(Level : AlertType) return integer is
  ------------------------------------------------------------
    variable result : integer ;
  begin
    -- synthesis translate_off
    result := AlertLogStruct.GetAlertStopCount(ALERTLOG_BASE_ID, Level) ;
    -- synthesis translate_on
    return result ;
  end function GetAlertStopCount ;


  ------------------------------------------------------------
  procedure SetAlertLogOptions (
  ------------------------------------------------------------
    FailOnWarning         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    FailOnDisabledErrors  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    ReportHierarchy       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertErrorCount  : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertLevel       : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertName        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteAlertTime        : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogErrorCount    : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogLevel         : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogName          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    WriteLogTime          : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    PrintPassed           : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    PrintAffirmations     : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    PrintDisabledAlerts   : AlertLogOptionsType := OPT_INIT_PARM_DETECT ;
    AlertPrefix           : string := OSVVM_STRING_INIT_PARM_DETECT ;
    LogPrefix             : string := OSVVM_STRING_INIT_PARM_DETECT ;
    ReportPrefix          : string := OSVVM_STRING_INIT_PARM_DETECT ;
    DoneName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    PassName              : string := OSVVM_STRING_INIT_PARM_DETECT ;
    FailName              : string := OSVVM_STRING_INIT_PARM_DETECT
  ) is
  begin
    -- synthesis translate_off
    AlertLogStruct.SetAlertLogOptions (
      FailOnWarning         => FailOnWarning       ,
      FailOnDisabledErrors  => FailOnDisabledErrors,
      ReportHierarchy       => ReportHierarchy     ,
      WriteAlertErrorCount  => WriteAlertErrorCount     ,
      WriteAlertLevel       => WriteAlertLevel     ,
      WriteAlertName        => WriteAlertName     ,
      WriteAlertTime        => WriteAlertTime      ,
      WriteLogErrorCount    => WriteLogErrorCount       ,
      WriteLogLevel         => WriteLogLevel       ,
      WriteLogName          => WriteLogName       ,
      WriteLogTime          => WriteLogTime        ,
      PrintPassed           => PrintPassed     ,
      PrintAffirmations     => PrintAffirmations     ,
      PrintDisabledAlerts   => PrintDisabledAlerts   ,
      AlertPrefix           => AlertPrefix         ,
      LogPrefix             => LogPrefix           ,
      ReportPrefix          => ReportPrefix        ,
      DoneName              => DoneName            ,
      PassName              => PassName            ,
      FailName              => FailName
    );
    -- synthesis translate_on
  end procedure SetAlertLogOptions ;

  ------------------------------------------------------------
  procedure ReportAlertLogOptions is
  ------------------------------------------------------------
  begin
    -- synthesis translate_off
    AlertLogStruct.ReportAlertLogOptions ;
    -- synthesis translate_on
  end procedure ReportAlertLogOptions ;



  -- synthesis translate_off

  ------------------------------------------------------------
  impure function GetAlertLogFailOnWarning        return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailOnWarning ;
  end function GetAlertLogFailOnWarning ;

  ------------------------------------------------------------
  impure function GetAlertLogFailOnDisabledErrors return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailOnDisabledErrors ;
  end function GetAlertLogFailOnDisabledErrors ;

  ------------------------------------------------------------
  impure function GetAlertLogReportHierarchy      return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogReportHierarchy ;
  end function GetAlertLogReportHierarchy ;

  ------------------------------------------------------------
  impure function GetAlertLogFoundReportHier       return boolean is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFoundReportHier ;
  end function GetAlertLogFoundReportHier ;

  ------------------------------------------------------------
  impure function GetAlertLogFoundAlertHier       return boolean is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFoundAlertHier ;
  end function GetAlertLogFoundAlertHier ;
  
  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertErrorCount return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertErrorCount ;
  end function GetAlertLogWriteAlertErrorCount ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertLevel      return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertLevel ;
  end function GetAlertLogWriteAlertLevel ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertName       return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertName ;
  end function GetAlertLogWriteAlertName ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteAlertTime       return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteAlertTime ;
  end function GetAlertLogWriteAlertTime ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogErrorCount return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogErrorCount ;
  end function GetAlertLogWriteLogErrorCount ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogLevel        return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogLevel ;
  end function GetAlertLogWriteLogLevel ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogName         return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogName ;
  end function GetAlertLogWriteLogName ;

  ------------------------------------------------------------
  impure function GetAlertLogWriteLogTime         return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogWriteLogTime ;
  end function GetAlertLogWriteLogTime ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintPassed    return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrintPassed ;
  end function GetAlertLogPrintPassed ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintAffirmations    return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrintAffirmations ;
  end function GetAlertLogPrintAffirmations ;

  ------------------------------------------------------------
  impure function GetAlertLogPrintDisabledAlerts  return AlertLogOptionsType is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPrintDisabledAlerts ;
  end function GetAlertLogPrintDisabledAlerts ;

  ------------------------------------------------------------
  impure function GetAlertLogAlertPrefix          return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogAlertPrefix ;
  end function GetAlertLogAlertPrefix ;

  ------------------------------------------------------------
  impure function GetAlertLogLogPrefix            return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogLogPrefix ;
  end function GetAlertLogLogPrefix ;

  ------------------------------------------------------------
  impure function GetAlertLogReportPrefix return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogReportPrefix ;
  end function GetAlertLogReportPrefix ;

  ------------------------------------------------------------
  impure function GetAlertLogDoneName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogDoneName ;
  end function GetAlertLogDoneName ;

  ------------------------------------------------------------
  impure function GetAlertLogPassName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogPassName ;
  end function GetAlertLogPassName ;

  ------------------------------------------------------------
  impure function GetAlertLogFailName return string is
  ------------------------------------------------------------
  begin
    return AlertLogStruct.GetAlertLogFailName ;
  end function GetAlertLogFailName ;

  ------------------------------------------------------------
  function IsLogEnableType (Name : String) return boolean is
  ------------------------------------------------------------
  -- type LogType is (ALWAYS, DEBUG, FINAL, INFO, PASSED) ;  -- NEVER
  begin
    if    Name = "PASSED" then return TRUE ;
    elsif Name = "DEBUG" then return TRUE ;
    elsif Name = "FINAL" then return TRUE ;
    elsif Name = "INFO"  then return TRUE ;
    end if ;
    return FALSE ;
  end function IsLogEnableType ;

  ------------------------------------------------------------
  procedure ReadLogEnables (file AlertLogInitFile : text) is
  --  Preferred Read format
  --  Line 1:  instance1_name log_enable log_enable log_enable
  --  Line 2:  instance2_name log_enable log_enable log_enable
  --  when reading multiple log_enables on a line, they must be separated by a space
  --
  --- Also supports alternate format from Lyle/....
  --  Line 1:  instance1_name
  --  Line 2:  log enable
  --  Line 3:  instance2_name
  --  Line 4:  log enable
  --
  ------------------------------------------------------------
    type     ReadStateType is (GET_ID, GET_ENABLE) ;
    variable ReadState        : ReadStateType := GET_ID ;
    variable buf              : line ;
    variable Empty            : boolean ;
    variable MultiLineComment : boolean := FALSE ;
    variable Name             : string(1 to 80) ;
    variable NameLen          : integer ;
    variable AlertLogID       : AlertLogIDType ;
    variable ReadAnEnable     : boolean ;
    variable LogLevel         : LogType ;
  begin
    ReadState := GET_ID ;
    ReadLineLoop : while not EndFile(AlertLogInitFile) loop
      ReadLine(AlertLogInitFile, buf) ;
      if ReadAnEnable then
        -- Read one or more enable values, next line read AlertLog name
        -- Note that any newline with ReadAnEnable TRUE will result in
        -- searching for another AlertLogID name - this includes multi-line comments.
        ReadState := GET_ID ;
      end if ;

      ReadNameLoop : loop
        EmptyOrCommentLine(buf, Empty, MultiLineComment) ;
        next ReadLineLoop when Empty ;

        case ReadState is
          when GET_ID =>
            sread(buf, Name, NameLen) ;
            exit ReadNameLoop when NameLen = 0 ;
            AlertLogID := GetAlertLogID(Name(1 to NameLen), ALERTLOG_ID_NOT_ASSIGNED) ;
            ReadState := GET_ENABLE ;
            ReadAnEnable := FALSE ;

          when GET_ENABLE =>
            sread(buf, Name, NameLen) ;
            exit ReadNameLoop when NameLen = 0 ;
            ReadAnEnable := TRUE ;
            if not IsLogEnableType(Name(1 to NameLen)) then
              Alert(OSVVM_ALERTLOG_ID, "AlertLogPkg.ReadLogEnables: Found Invalid LogEnable: " & Name(1 to NameLen)) ;
              exit ReadNameLoop ;
            end if ;
            LogLevel := LogType'value(Name(1 to NameLen)) ;
            SetLogEnable(AlertLogID, LogLevel, TRUE) ;
        end case ;
      end loop ReadNameLoop ;
    end loop ReadLineLoop ;
  end procedure ReadLogEnables ;

  ------------------------------------------------------------
  procedure ReadLogEnables (FileName : string) is
  ------------------------------------------------------------
    file AlertLogInitFile : text open READ_MODE is FileName ;
  begin
    ReadLogEnables(AlertLogInitFile) ;
  end procedure ReadLogEnables ;

  ------------------------------------------------------------
  function PathTail (A : string) return string is
  ------------------------------------------------------------
    alias aA : string(1 to A'length) is A ;
    variable LenA : integer := A'length ;
  begin
    if aA(LenA) = ':' then
      LenA := LenA - 1 ;
    end if ;
    for i in LenA downto 1 loop
      if aA(i) = ':' then
        return aA(i+1 to LenA)  ;
      end if ;
    end loop ;
    return aA(1 to LenA) ;
  end function PathTail ;


  -- synthesis translate_on


  --  ------------------------------------------------------------
  -- Deprecated
  --

  ------------------------------------------------------------
  -- deprecated
  procedure AlertIf( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) is
  begin
    -- synthesis translate_off
    AlertIf( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
  end procedure AlertIf ;

  ------------------------------------------------------------
  -- deprecated
  impure function  AlertIf( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean is
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertIf( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
    return result ;
  end function AlertIf ;

  ------------------------------------------------------------
  -- deprecated
  procedure AlertIfNot( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) is
  begin
    -- synthesis translate_off
    AlertIfNot( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
  end procedure AlertIfNot ;

  ------------------------------------------------------------
  -- deprecated
  impure function  AlertIfNot( condition : boolean ; AlertLogID  : AlertLogIDType ; Message : string ; Level : AlertType := ERROR ) return boolean is
    variable result : boolean ;
  begin
    -- synthesis translate_off
    result := AlertIfNot( AlertLogID, condition, Message, Level) ;
    -- synthesis translate_on
    return result ;
  end function AlertIfNot ;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf(
    AlertLogID   : AlertLogIDType ;
    condition    : boolean ;
    Message      : string ;
    LogLevel     : LogType  ;  -- := PASSED
    AlertLevel   : AlertType := ERROR
  ) is
  begin
    -- synthesis translate_off
    if condition then
      -- PASSED.  Count affirmations and PASSED internal to LOG to catch all of them
      AlertLogStruct.Log(AlertLogID, Message, LogLevel) ; -- call log
    else
      AlertLogStruct.IncAffirmCount(AlertLogID) ;  -- count the affirmation
      AlertLogStruct.Alert(AlertLogID, Message, AlertLevel) ; -- signal failure
    end if ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf( AlertLogID : AlertLogIDType ; condition : boolean ; Message : string ; AlertLevel : AlertType ) is
  begin
    -- synthesis translate_off
    AffirmIf(AlertLogID, condition, Message, PASSED, AlertLevel) ;
    -- synthesis translate_on
  end procedure AffirmIf ;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf(condition : boolean ; Message : string ;  LogLevel : LogType  ; AlertLevel : AlertType := ERROR) is
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, LogLevel, AlertLevel) ;
    -- synthesis translate_on
  end procedure AffirmIf;

  ------------------------------------------------------------
  -- deprecated
  procedure AffirmIf(condition : boolean ; Message : string ;  AlertLevel : AlertType ) is
  begin
    -- synthesis translate_off
    AffirmIf(ALERT_DEFAULT_ID, condition, Message, PASSED, AlertLevel) ;
    -- synthesis translate_on
  end procedure AffirmIf;

end package body AlertLogPkg ;