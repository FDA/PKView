using SasJobs.Api.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Http;
using System.Web.Http.Dispatcher;

namespace SasJobs.Api
{
    public static class WebApiConfig
    {
        /// <summary>
        /// Register Web Api routes and filters
        /// </summary>
        /// <param name="config"></param>
        public static void Register(HttpConfiguration config)
        {
            // Web API routes
            config.MapHttpAttributeRoutes();

            config.Routes.MapHttpRoute(
                name: "DefaultApi",
                routeTemplate: "api/{controller}/{id}",
                defaults: new { id = RouteParameter.Optional }
            );

            // Return exceptions as errors to the client
            config.Filters.Add(new ExceptionHandlingFilterAttribute());

            config.EnsureInitialized();
        }
    }
}
