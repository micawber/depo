@REM $Header$
@REM
@REM bcpyrght
@REM ***************************************************************************
@REM * $Copyright: Copyright (c) 2022 Veritas Technologies LLC. All rights reserved $ *
@REM ***************************************************************************
@REM ecpyrght
@REM                                                                          -
@REM  HOW TO SEND DR MAIL FROM THE NT NETBACKUP SERVER                        -
@REM                                                                          -
@REM  NetBackup DR protection checks if the mail script                       -
@REM  (NetBackup\Bin\mail_dr_info.cmd) exists.  If the script exists          -
@REM  NetBackup DR protection runs it passing four parameters on the          -
@REM  command line:                                                           -
@REM                                                                          -
@REM       %1 is the recipient's address                                      -
@REM       %2 is the subject line                                             -
@REM       %3 is the message file name                                        -
@REM       %4 is the attached file name                                       -
@REM                                                                          -
@REM PS> Unblock-File -path "X:\Program Files\Veritas\NetBackup\bin\mail_dr_info.ps1"
@REM PS> Get-ExecutionPolicy -List                                            -
@REM PS> Set-Executionpolicy Unrestricted                                     -

@FOR /F "tokens=2,* skip=2" %%L IN ('reg query "HKLM\SOFTWARE\Veritas\NetBackup\CurrentVersion" /v INSTALLDIR') DO @SET instpath=%%M

@CALL PowerShell.exe -file "%instpath%NetBackup\bin\mail_dr_info.ps1" -sendto %1 -subj %2 -msgfile %3 -drfiles %4
