using iPortal.Models.OgdTool;
using System.IO;
using System.IO.Compression;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Web;
using System.Web.Hosting;
using System.Web.Http;

namespace iPortal.Controllers.OgdTool
{
    /// <summary>
    /// Script generator controller
    /// </summary>

    public class GenerateScriptController : ApiController
    {
        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/ogdtool/createscript"), HttpPost]
        public void Post(string submissionId, string projectName, [FromBody]TreatmentComparison comparison)
        {
            var generator = new OgdScriptGenerator(submissionId, projectName, comparison);
            generator.Create();

            var zipFilename = Path.ChangeExtension(generator.OutputFolder, "zip");
            if (File.Exists(zipFilename)) File.Delete(zipFilename);
            ZipFile.CreateFromDirectory(generator.OutputFolder, zipFilename);
        }
    }
}
