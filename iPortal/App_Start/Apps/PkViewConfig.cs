using iPortal.Controllers;
namespace iPortal.Config
{
    public static class PkViewConfig
    {
        public static string NdaRootFolder { get { 
            return string.Format(@"\\{0}\clinical\", iPortalApp.AppServerName); } }

        public static string OutputFolder { get { 
            return string.Format(@"\\{0}\Output Files\PKView\[USER]\", iPortalApp.AppServerName); } }

        public static void Init()
        {
            DownloadController.Repositories.Add("PkView", OutputFolder);
        }
    }
}