using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;

namespace iPortal.Models.OgdTool
{
    public class VariableMappings
    {
        /// <summary> List of common variables across the files, used to
        /// map identifier variables like subject, treatment, sequence and group</summary>
        public List<Variable> CommonVariables { get; set; }

        /// <summary> Variable mappings common to all files</summary>
        public List<VariableMapping> CommonVariableMappings { get; set; }

        public List<ArrayVariable> ArrayVariables { get; set; }

        public List<VariableMapping> ArrayVariableMappings { get; set; }

        public List<VariableValue> NominalTimes { get; set; }
    }

    public class Variable
    {
        public string Name { get; set; }
        public List<string> Values { get; set; }
    }

    public class ArrayVariable
    {
        public string Pattern { get; set; }
        public int Min { get; set; }
        public int Max { get; set; }
        public string File { get; set; }
    }

    public class VariableMapping
    {
        public string TargetVariable { get; set; }
        public string FileVariable { get; set; }
    }

    public class VariableValue {
        public string Variable { get; set; }
        public double Value { get; set; }
    }
}