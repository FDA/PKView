using SASObjectManager;
using System;

namespace SasJobs.Bridge
{
    /// <summary>
    /// Represents a SAS Workspace pool
    /// </summary>
    public class SasWsPool : ISasWsPool
    {
        /// <summary>
        /// Gets or sets the low level SAS Workspace pool
        /// </summary>
        private IObjectPool workspacePool { get; set; }

        /// <summary>
        /// Lock object for concurrent access to the pool
        /// </summary>
        private Object poolLock = new Object();

        /// <summary>
        /// Creates a SAS Workspace pool
        /// </summary>
        public SasWsPool()
        {
            var myObjectFactory = new ObjectFactory();
            var myServerDef = new ServerDef();
            var myLoginDef = new LoginDef();
            myServerDef.MachineDNSName = "localhost";
            myServerDef.Protocol = Protocols.ProtocolCom;
            myLoginDef.LoginName = Environment.UserName;
            myLoginDef.MinSize = 30;
            myLoginDef.MinAvail = 2;

            // Clear all existing object pools (this server should not be running any other)
            foreach (ObjectPool pool in myObjectFactory.ObjectPools)
                pool.Shutdown();

            // Create a new workspace pool
            workspacePool = myObjectFactory.ObjectPools
                .CreatePoolByServer("WebServicePool", myServerDef, myLoginDef);
            //ObjectKeeper keeper = new ObjectKeeper();
            //keeper.AddObject(1, "SASServer", workspacePool);
        }
 
        /// <summary>
        /// Creates or gets a workspace in the pool
        /// </summary>
        /// <returns>A SAS pooled workspace or null if the pool is full/busy</returns>
        public IPooledObject  GetWorkspace()
        {
            try
            {
                lock (poolLock)
                {
                    Console.WriteLine(String.Format("Available workspaces {0}/{1}",
                        workspacePool.AvailableCount, workspacePool.TotalCount));
                    return workspacePool.GetPooledObject("", "", 10000);                    
                }
            }
            catch (System.Runtime.InteropServices.COMException)
            {
                return null;
            }
        }

        /// <summary>
        /// Shuts down the workspace pool
        /// </summary>
        ~SasWsPool()
        {
            var myObjectFactory = new ObjectFactory();

            // Clear all existing object pools (this server should not be running any other)
            foreach (ObjectPool pool in myObjectFactory.ObjectPools)
                pool.Shutdown(); 
        }
    }
}
