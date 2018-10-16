using System;
using System.Collections;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration.Install;
using System.Linq;
using System.ServiceProcess;
using System.Threading.Tasks;

namespace SasJobs.WindowsService
{
    /// <summary>
    /// Provide the ProjectInstaller class which allows 
    /// the service to be installed by the Installutil.exe tool
    /// </summary>
    [RunInstaller(true)]
    public partial class SasJobsServiceInstaller : Installer
    {
        private ServiceProcessInstaller processInstaller;
        private ServiceInstaller serviceInstaller;
        private string serviceName = "SasJobsWindowsService";

        public SasJobsServiceInstaller()
        {
            this.processInstaller = new ServiceProcessInstaller();
            this.serviceInstaller = new ServiceInstaller();

            // The following line instructs the installer to prompt for the account to run the service
            this.processInstaller.Account = ServiceAccount.NetworkService;
            this.processInstaller.Username = null;
            this.processInstaller.Password = null;

            this.serviceInstaller.DisplayName = "OCP SAS Jobs Service";
            this.serviceInstaller.StartType = ServiceStartMode.Automatic;

            this.serviceInstaller.ServiceName = this.serviceName;

            Installers.Add(this.processInstaller);
            Installers.Add(this.serviceInstaller);

            this.Committed += new InstallEventHandler(this.committedHandler);
        }

        /// <summary>
        /// Installer commited event triggered after the installer has finished
        /// </summary>
        /// <param name="sender"></param>
        /// <param name="e"></param>
        private void committedHandler(object sender, InstallEventArgs e)
        { 
            // Auto start the service
            var controller = new ServiceController(serviceName);
            controller.Start();
        }
        
    }
}
