using System;
using System.Collections.Generic;
using System.DirectoryServices.AccountManagement;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Hosting;
using System.Xml.Serialization;

namespace iPortal.Models
{
    public class XmlUserData
    {
        /// <summary> Default root path to save and retireve user xml data </summary>
        public static string DefaultRoot { 
            get { return HostingEnvironment.MapPath("/App_Data/userData"); }
        }

        /// <summary> Root path to save and retrieve xml data</summary>
        private static string savePath = DefaultRoot;
        
        /// <summary>
        /// Switch xml root to a new folder
        /// </summary>
        /// <param name="newRoot"></param>
        public static bool SwitchRoot(string newRoot) {
            if (!Directory.Exists(newRoot)) return false;
            savePath = newRoot;
            return true;
        }

        /// <summary>
        /// Save a config file
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="data"></param>
        /// <param name="name"></param>
        /// <param name="section"></param>
        /// <param name="user"></param>
        public static void Save<T>(T data, string name, string section = null, string user = null)
        {
            TextWriter writer = null;
            try
            {
                var serializer = new XmlSerializer(typeof(T));
                writer = new StreamWriter(getUserPath(section, user) + '\\' + name + ".xml", false);
                serializer.Serialize(writer, data);
            }
            finally
            {
                if (writer != null)
                    writer.Close();
            }
        }

        /// <summary>
        /// Load a config file
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name"></param>
        /// <param name="section"></param>
        /// <param name="user"></param>
        /// <returns></returns>
        public static T Load<T>(string name, string section = null, string user = null) where T: new()
        {
            TextReader reader = null;
            try
            {              
                var serializer = new XmlSerializer(typeof(T));
                reader = new StreamReader(getUserPath(section, user) + '\\' + name + ".xml");
                return (T)serializer.Deserialize(reader);
            }
            finally
            {
                if (reader != null)
                    reader.Close();
            }
        }

        /// <summary>
        /// Delete a config file
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name"></param>
        /// <param name="section"></param>
        /// <param name="user"></param>
        /// <returns></returns>
        public static bool Delete(string name, string section = null, string user = null)
        {
            var configFile = new FileInfo(getUserPath(section, user) + '\\' + name + ".xml");
            
            if (!configFile.Exists) return false;

            configFile.Delete();
            return true;
        }

        /// <summary>
        /// Find configuration files by a string pattern
        /// </summary>
        /// <param name="pattern">Search pattern</param>
        /// <param name="section">configuration section</param>
        /// <returns>a list of configuration files that follow the pattern</returns>
        public static IEnumerable<string> Find(string pattern, string section = null, string userName = null)
        {
            return FindFiles(pattern, section, userName).Select(f => f.Name.Replace(".xml", ""));
        }

        /// <summary>
        /// Find configuration files by a string pattern
        /// </summary>
        /// <param name="pattern">Search pattern</param>
        /// <param name="section">configuration section</param>
        /// <returns>a list of configuration files that follow the pattern</returns>
        public static IEnumerable<FileInfo> FindFiles(string pattern, string section = null, string userName = null)
        {
            var userDirectory = new DirectoryInfo(getUserPath(section, userName));
            var filesInDir = userDirectory.GetFiles(pattern + ".xml");

            return filesInDir;
        }

        /// <summary>
        /// Returns true if configuration file exists
        /// </summary>
        /// <param name="name">name of the configuration file</param>
        /// <param name="section">configuration section</param>
        /// <returns>true if file exists</returns>
        public static bool Exists(string name, string section = null, string userName = null)
        {
            var userDirectory = new DirectoryInfo(getUserPath(section, userName));         
            var filesInDir = userDirectory.GetFiles(name + ".xml");

            return filesInDir.Any();
        }

        /// <summary>
        /// Import a settings file from another user
        /// </summary>
        /// <param name="name">Settings file name</param>
        /// <param name="userName">Original owner</param>
        /// <param name="section">configuration section</param>
        /// <returns>true if settings were copied succesfully</returns>
        public static bool Import(string name, string userName, string section = null)
        {
            var configFile = new FileInfo(getUserPath(section, userName) + '\\' + name + ".xml");
            string newPath = getUserPath(section) + "\\" + configFile.Name;
            var newFile = configFile.CopyTo(newPath, true);
            return newFile.Exists;
        }

        /// <summary>
        /// Get the list of users with stored user configuration
        /// </summary>
        /// <returns>The list of users</returns>
        public static IEnumerable<UserPrincipal> GetUsers(PrincipalContext context)
        {
            var userFolders = new System.IO.DirectoryInfo(savePath).GetDirectories();
            return userFolders.SelectMany(userFolder =>
            {
                var principal = UserPrincipal.FindByIdentity(context, userFolder.Name);
                if (principal == null) return new UserPrincipal[] {};
                else return new[] { principal };
            }).ToList();
        }

        /// <summary>
        /// Find the specific configuration path given a user and section
        /// </summary>
        /// <param name="section">configuration section</param>
        /// <param name="userName">user name, the current user will be used if not specified</param>
        /// <returns>the path to the user's configuration files</returns>
        private static string getUserPath(string section = null, string userName = null)
        {
            // If user name is not specified retrieve user path for the current user
            if (userName == null)
                userName = HttpContext.Current.User.Identity.Name ?? "DEFAULT";
            userName = userName.Substring(userName.LastIndexOfAny(new[] { '/', '\\' }) + 1);
            var userPath = savePath + '\\' + userName.Replace(' ','_');

            if (!String.IsNullOrWhiteSpace(section)) userPath += '\\' + section;

            if (!Directory.Exists(userPath))
                Directory.CreateDirectory(userPath);

            return userPath;
        }

    }
}