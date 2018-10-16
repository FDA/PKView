@echo off
mkdir SasJobsService
mkdir SasJobsService\bin
del /s /q SasJobsService\bin\*
copy ..\bin\Debug\* SasJobsService\bin\
copy scripts\* SasJobsService\