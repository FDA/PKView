using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Linq;
using System.ServiceModel;
using System.ServiceProcess;
using System.Text;
using System.Threading.Tasks;

namespace SasJobs.WindowsService
{
    public partial class SasJobsWindowsService : ServiceBase
    {
        /// <summary>
        /// Service host for the WCF service
        /// </summary>
        public ServiceHost serviceHost = null;

        /// <summary>
        /// SAS jobs windows service constructor
        /// </summary>
        public SasJobsWindowsService()
        {
            this.ServiceName = "SasJobsService";
        }

        /// <summary>
        /// Start the windows service 
        /// </summary>
        /// <param name="args"></param>
        protected override void OnStart(string[] args)
        {
            if (serviceHost != null)
            {
                serviceHost.Close();
            }

            // Create a ServiceHost for the SasJobsService type
            serviceHost = new ServiceHost(typeof(SasJobs.BackgroundWorker.SasJobsService));

            // Open the ServiceHostBase to create listeners and listen for messages
            serviceHost.Open();
        }

        /// <summary>
        /// Stop the windows service
        /// </summary>
        protected override void OnStop()
        {
            if (serviceHost != null)
            {
                serviceHost.Close();
                serviceHost = null;
            }
        }
    }
}
