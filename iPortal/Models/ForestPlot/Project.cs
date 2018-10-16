using System.Collections.Generic;

namespace iPortal.Models.ForestPlot
{
    public class Project
    {
        public int Id;
        public string ProjectName = "";
        public string FileName = "";
        public int PlotNumbers;
        public List<Plot> Plots;
    }

    public class Plot
    {
        public int Id;
        public PlotSettings Settings;
        public List<PlotData> Rows;
    }

    public class PlotSettings
    {
        public string DrugName = "";
        public string Title = "";
        public string FootNote = "";
        public string Xlabel = "";
        public double? RangeBottom;
        public double? RangeTop;
        public double? RangeStep;
        public int Style;
        public int Scale;
    }

    public class PlotData
    {
        public string Category = "";
        public string SubCategory = "";
        public string Parameter = "";
        public string Comment = "";
        public double? Ratio;
        public double? Lower_CI;
        public double? Upper_CI;
    }
}
