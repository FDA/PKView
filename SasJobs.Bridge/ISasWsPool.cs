using SASObjectManager;

namespace SasJobs.Bridge
{
    /// <summary>
    /// Allows manipulation of a SAS workspace pool
    /// </summary>
    public interface ISasWsPool
    {
        /// <summary>
        /// Creates or gets a workspace in the pool
        /// </summary>
        /// <returns>A SAS pooled workspace or null if the pool is full/busy</returns>
        IPooledObject GetWorkspace();
    }
}
