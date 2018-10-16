@echo off
mkdir SasJobsService
mkdir SasJobsService\bin
mkdir SasJobsService\Logs
mkdir SasJobsService\Logs\SAS
mkdir "SasJobsService\Stored Procedures"
del /s /q SasJobsService\bin\*
copy ..\bin\Release\* SasJobsService\bin\
copy scripts\* SasJobsService\