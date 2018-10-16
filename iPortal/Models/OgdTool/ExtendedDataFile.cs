using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;

namespace iPortal.Models.OgdTool
{
    public class ExtendedDataFile : DataFile
    {
        public DataTable Data { get; set; }

        public List<string> Variables { get; set; }

        public List<ArrayVariable> ArrayVariables { get; set; }
        
    }
}