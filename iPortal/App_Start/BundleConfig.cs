using System;
using System.Web.Optimization;

namespace iPortal {
  public class BundleConfig {
    public static void RegisterBundles(BundleCollection bundles) {
      bundles.IgnoreList.Clear();
      AddDefaultIgnorePatterns(bundles.IgnoreList);

      bundles.Add(
        new ScriptBundle("~/lib/vendor")
          .Include("~/Scripts/bootstrap-fileupload.min.js")
          .Include("~/Scripts/bootstrap-slider.js")          
        );

      bundles.Add(
        new StyleBundle("~/lib/css")

          // Must be first. IE10 mobile viewport fix
          .Include("~/Lib/ie10mobile.css")

          // Bootstrap and plugins/wigdets
          .Include("~/Lib/bootstrap/bootstrap.boostwatch.min.css")
          //.Include("~/Lib/bootstrap/bootstrap-theme.min.css") // Boostwatch's template does not use a theme
          .Include("~/Lib/selectize/css/selectize.css")
          .Include("~/Lib/selectize/css/selectize.bootstrap3.css")
          .Include("~/Lib/dataTables/bootstrap/dataTables.bootstrap.css")         
          .Include("~/Lib/font-awesome/css/font-awesome.min.css")

          //.Include("~/Content/typeahead.js-bootstrap.css")
          .Include("~/Content/bootstrap-fileupload.css")         
          .Include("~/Content/slider.css")          

          // Durandal stylesheet
		  .Include("~/Lib/durandal/css/durandal.css")

          // Application stylesheets
          .Include("~/Content/styles/app.css")
          .Include("~/Content/styles/iPortal.css")
        );

      // disable bundling and minification until further testing, even in production (FIXME)
      BundleTable.EnableOptimizations = false;
    }

    public static void AddDefaultIgnorePatterns(IgnoreList ignoreList) {
      if(ignoreList == null) {
        throw new ArgumentNullException("ignoreList");
      }

      ignoreList.Ignore("_references.js");
      ignoreList.Ignore("*.intellisense.js");
      ignoreList.Ignore("*-vsdoc.js");
      ignoreList.Ignore("*.debug.js", OptimizationMode.WhenEnabled);
    }
  }
}