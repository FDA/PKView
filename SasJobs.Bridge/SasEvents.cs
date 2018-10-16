using System;

namespace SasJobs.Bridge
{
    /// <summary>
    /// Represents a set of SAS events.
    /// </summary>
    public class SasEvents : ISasEvents
    {
        /// <summary>
        /// Delegate type for error event handlers
        /// </summary>
        public delegate void ErrorHandler();

        /// <summary>
        /// Delegate type for done event handlers
        /// </summary>
        /// <param name="rc">Return code</param>
        public delegate void DoneHandler(int rc);

        /// <summary>
        /// Delegate type for procedure start events
        /// </summary>
        /// <param name="procName">procedure name</param>
        public delegate void ProcStartHandler(string procName);

        /// <summary>
        /// Delegate type for procedure complete events
        /// </summary>
        /// <param name="procName">procedure name</param>
        public delegate void ProcCompleteHandler(string procName);

        /// <summary>
        /// Delegate type for data step start events
        /// </summary>
        public delegate void DataStepStartHandler();

        /// <summary>
        /// Delegate type for data step complete events
        /// </summary>
        public delegate void DataStepCompleteHandler();

         /// <summary>
        /// Event that clients can use to be notified of an error
        /// </summary>
        public event ErrorHandler Error;

        /// <summary>
        /// Event that clients can use to be notified that SAS 
        /// has finished executing the submitted code
        /// </summary>
        public event DoneHandler Done;

        /// <summary>
        /// Event that clients can use to be notified that a SAS 
        /// procedure has started executing
        /// </summary>
        public event ProcStartHandler ProcStart;

        /// <summary>
        /// Event that clients can use to be notified that a SAS
        /// procedure has finished executing
        /// </summary>
        public event ProcCompleteHandler ProcComplete;

        /// <summary>
        /// Event that clients can use to be notified that a SAS
        /// data step has started
        /// </summary>
        public event DataStepStartHandler DataStepStart;

        /// <summary>
        /// Event that clients can use to be notified that a SAS
        /// data step has completed
        /// </summary>
        public event DataStepCompleteHandler DataStepComplete;

        /// <summary>
        /// Handle SAS events from a particular language service
        /// </summary>
        /// <param name="languageService">a SAS language service</param>
        public void hook(SAS.ILanguageService languageService)
        {
            ((SAS.LanguageService)languageService).StepError +=
              new SAS.CILanguageEvents_StepErrorEventHandler(sasErrorHandler);
            ((SAS.LanguageService)languageService).SubmitComplete +=
              new SAS.CILanguageEvents_SubmitCompleteEventHandler(sasSubmitCompleteHandler);
            ((SAS.LanguageService)languageService).DatastepStart +=
                new SAS.CILanguageEvents_DatastepStartEventHandler(sasDataStepStartHandler);
            ((SAS.LanguageService)languageService).DatastepComplete +=
                new SAS.CILanguageEvents_DatastepCompleteEventHandler(sasDataStepCompleteHandler);
            ((SAS.LanguageService)languageService).ProcStart +=
                new SAS.CILanguageEvents_ProcStartEventHandler(sasProcStartHandler);
            ((SAS.LanguageService)languageService).ProcComplete +=
                new SAS.CILanguageEvents_ProcCompleteEventHandler(sasProcCompleteHandler);
        }

        /// <summary>
        /// Detach events from the language service
        /// </summary>
        /// <param name="languageService">a SAS language service</param>
        public void unhook(SAS.ILanguageService languageService)
        {
            ((SAS.LanguageService)languageService).StepError -=
              new SAS.CILanguageEvents_StepErrorEventHandler(sasErrorHandler);
            ((SAS.LanguageService)languageService).SubmitComplete -=
              new SAS.CILanguageEvents_SubmitCompleteEventHandler(sasSubmitCompleteHandler);
            ((SAS.LanguageService)languageService).DatastepStart -=
                new SAS.CILanguageEvents_DatastepStartEventHandler(sasDataStepStartHandler);
            ((SAS.LanguageService)languageService).DatastepComplete -=
                new SAS.CILanguageEvents_DatastepCompleteEventHandler(sasDataStepCompleteHandler);
            ((SAS.LanguageService)languageService).ProcStart -=
                new SAS.CILanguageEvents_ProcStartEventHandler(sasProcStartHandler);
            ((SAS.LanguageService)languageService).ProcComplete -=
                new SAS.CILanguageEvents_ProcCompleteEventHandler(sasProcCompleteHandler);
        }

        /// <summary>
        /// Handle SAS step error event
        /// </summary>
        private void sasErrorHandler()
        {
            if (Error != null) Error();  
        }

        /// <summary>
        /// Handle SAS submited code completed event
        /// </summary>
        /// <param name="sasRC">return code</param>
        private void sasSubmitCompleteHandler(int sasRC)
        {
            if (Done != null) Done(sasRC);
        }

        /// <summary>
        /// Handle SAS procedure start event
        /// </summary>
        /// <param name="procedureName">procedure name</param>
        private void sasProcStartHandler(string procedureName)
        {
            //Console.WriteLine("Procedure Start: " + procedureName);
            if (ProcStart != null) ProcStart(procedureName);
        }

        /// <summary>
        /// Handle SAS procedure complete event
        /// </summary>
        /// <param name="procedureName">procedure name</param>
        private void sasProcCompleteHandler(string procedureName)
        {
            //Console.WriteLine("Procedure End: " + procedureName);
            if (ProcComplete != null) ProcComplete(procedureName);
        }

        /// <summary>
        /// Handle SAS data step start event
        /// </summary>
        private void sasDataStepStartHandler()
        {
            //Console.WriteLine("Data Step Start");
            if (DataStepStart != null) DataStepStart();
        }

        /// <summary>
        /// Handle SAS data step complete event
        /// </summary>
        private void sasDataStepCompleteHandler()
        {
            //Console.WriteLine("Data Step End");
            if (DataStepComplete != null) DataStepComplete();
        }
    }
}
