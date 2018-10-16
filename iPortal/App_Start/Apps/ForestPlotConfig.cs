using System;
namespace iPortal.Config
{
    public static class ForestPlotConfig
    {
        public static string OutputFolder { get {
            return String.Format(@"\\{0}\Output Files\ForestPlot\", iPortalApp.AppServerName); } }  
        
        public static void Init()
        {
        }
    }
}