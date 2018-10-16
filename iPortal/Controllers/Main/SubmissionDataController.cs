using System.Collections.Generic;
using System.Linq;
using System.Web.Http;
using iPortal.Config;

namespace iPortal.Controllers
{
    /// <summary>
    /// Search service controller
    /// </summary>

    public class SubmissionsDataController : ApiController
    {
        /// <summary>
        /// Main Get function
        /// </summary>
        /// <returns>A list of results</returns>
        [Route("api/submissions")]
        public IEnumerable<string> Get(string filter = "ANDA,BLA,NDA,STN,IND,MF,DRUG")
        {
            // Retrieve the list of nda folders
            var dir = new System.IO.DirectoryInfo(PkViewConfig.NdaRootFolder);
            var NdaFolders = dir.GetDirectories().Where(d =>
            {
                foreach (string prefix in filter.Split(','))
                {
                    if (d.Name.StartsWith(prefix.Trim()))
                        return true;
                }
                return false;
            });

            var ndaList = NdaFolders.Select(d => d.Name);

            return ndaList;
        }

    }
}
