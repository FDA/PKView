using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web.Http;
using iPortal.App_Data;
using iPortal.Config;
using iPortal.Models.ForestPlot;
using System.Web.Script.Serialization;
using iPortal.Models;
using SasJobs.ClientLibrary;

namespace iPortal.Controllers.ForestPlot
{
    public class GeneratePlotController : ApiController
    {
        /// <summary>
        /// The run function send request to SAS application server to generate plot 
        /// </summary>
        /// <returns>null if evertything ok or the error code</returns>
        [HttpGet, Route("api/forestplot/generateplot/run")]
        public string Run(string jsonPlot)
        {
            JavaScriptSerializer jss= new JavaScriptSerializer();
            Plot revisedPlot = jss.Deserialize<Plot>(jsonPlot); 

            // Use the iportal database context
            using (OCPSQLEntities db = new OCPSQLEntities())
            {
                // For each project, update the plot data in the database
                //FPTOOLS_PROJECT project = new FPTOOLS_PROJECT();
                var plot = new IPORTAL_FP();

                    // retrieve plot data from the database
                    plot = db.IPORTAL_FP.SingleOrDefault(p => p.FP_ID == revisedPlot.Id);
                    // if the plot does not exist return error TODO improve
                    if (plot == null) throw new Exception();

                    //  Update plot setting data into database
                    plot.DRUGNAME = revisedPlot.Settings.DrugName;
                    plot.TITLE = revisedPlot.Settings.Title;
                    plot.RANGE_BOTTOM = (double)revisedPlot.Settings.RangeBottom;
                    plot.RANGE_TOP = (double)revisedPlot.Settings.RangeTop;
                    plot.RANGE_STEP = (double)revisedPlot.Settings.RangeStep;                    
                    plot.XLABEL = revisedPlot.Settings.Xlabel;
                    plot.FOOTNOTE = revisedPlot.Settings.FootNote;                   
                    plot.SCALE_ID = revisedPlot.Settings.Scale;
                    plot.FP_STYLE_ID = revisedPlot.Settings.Style;
                   
                    db.SaveChanges();
                }

                // Run the analysis code
                var filename = "Forest_plot_" +  revisedPlot.Id;
                try
                {
                    SasClientObject.RunJob("GenForestPlot",
                        (new { IdName = "FP_ID", IdVal = revisedPlot.Id, PlotId = "Forest_plot" }));
                    //    new SasGenericClient.RunOptions {  
                        //    AbortExisting = true, RunId = "GenForestPlot" + revisedPlot.Id
                      //  });
                }
                catch (Exception ex) 
                {
                    return "";                                        
                }

            // Download the plot as a base64 encoded string 
            try
            {
                var result = new HttpResponseMessage(HttpStatusCode.OK);
                var stream = new FileStream(ForestPlotConfig.OutputFolder + filename + ".png", FileMode.Open);
                byte[] filebytes = new byte[stream.Length];
                stream.Read(filebytes, 0, Convert.ToInt32(stream.Length));
                var encodedImage = Convert.ToBase64String(filebytes);
                return "data:image/png;base64," + encodedImage;
            }
            catch (Exception ex)
            {
                return "";
            }
        }
    }
}
