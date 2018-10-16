using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http;
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;
using SolrNet;
using iPortal.Config;
using iPortal.Models;

namespace iPortal
{
    // Note: For instructions on enabling IIS6 or IIS7 classic mode, 
    // visit http://go.microsoft.com/?LinkId=9394801

    public class iPortalApp : System.Web.HttpApplication
    {
        public static string AppServerName 
        {
            get 
            { 
                return "localhost";
            } 
        }

        protected void Application_Start()
        {
            AreaRegistration.RegisterAllAreas();

            GlobalConfiguration.Configure(WebApiConfig.Register);
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);

            // Initialize applications
            PkViewConfig.Init();
            OgdToolConfig.Init();
            ForestPlotConfig.Init();

            // General iPortal initialization
            SasJobs.ClientLibrary.SasClientObject.Init(String.Format("http://{0}:5455/", AppServerName));
        }
    }
}