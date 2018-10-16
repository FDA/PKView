using System.Web.Http;

namespace SasJobs.Api
{
    public class WebApiApplication : System.Web.HttpApplication
    {
        public enum EnvironmentTypes { localhost};

        public static EnvironmentTypes EnvironmentType
        {
            get
            {
                switch (System.Net.Dns.GetHostName())
                {                    
                    default: 
                        return EnvironmentTypes.localhost;
                }
            }
        }

        protected void Application_Start()
        {
            WebApiConfig.Register(GlobalConfiguration.Configuration);          
        }
    }
}
