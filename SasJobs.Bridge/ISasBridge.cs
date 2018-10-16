using System;

namespace SasJobs.Bridge
{
    /// <summary>
    /// Allows execution of sas stored procedures
    /// </summary>
    public interface ISasBridge
    {
        /// <summary>
        /// Run a SAS stored procedure
        /// </summary>
        /// <param name="procedure">stored procedure name</param>
        /// <param name="xmlInputData">Input data encoded in xml format</param>
        /// <param name="xmlMap">SAS xml map that defines how sas will read the data</param>
        /// <returns>True in case of success, false if a workspace is 
        /// not available in the pool at this time</returns>       
        bool RunProcedure(string procedure, string xmlInputData, string xmlMap);

        /// <summary>
        /// Flush the SAS log
        /// </summary>
        /// <param name="log">log sink to use</param>
        /// <returns>Number of lines flushed</returns>
        int FlushLog(ISasLog log);

        /// <summary>
        /// Flush the sas output
        /// </summary>
        /// <param name="log">log sink to use</param>
        /// <returns>Number of lines flushed</returns>
        int FlushList(ISasLog log);

        /// <summary>
        /// Retrieve the SAS job results
        /// </summary>
        /// <returns>The job results in xml format</returns>
        string GetResult();

        /// <summary>
        /// Release the workspace back to the pool
        /// </summary>
        void Release();
    }
}
