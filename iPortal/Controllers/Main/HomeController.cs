using System.Web.Mvc;
using System.DirectoryServices.AccountManagement;
using System.Collections.Generic;
using System.IO;
using System.Web.Hosting;
using System.Xml.Serialization;
using System;

namespace iPortal.Controllers
{
    public class HomeController : Controller
    {

        /// <summary> Default root path to save and retireve user xml data </summary>
        public static string DefaultRoot
        {
            get { return HostingEnvironment.MapPath("/App_Data/userData"); }
        }
        public ActionResult Index()
        {
            ViewBag.UserFirstName = "set 8";
            ViewBag.UserLastName = "LastName";

            return View();
        }

        public string UserInTheList()
        {
            using (var context = new PrincipalContext(ContextType.Domain, "localhost"))
            {
                var principal = UserPrincipal.FindByIdentity(context, User.Identity.Name);
                if (principal != null)
                {
                    Userlist userlist;
                    userlist = LoadUserList<Userlist>();
                    DateTime logontime;
                    DateTime nowtime;
                    nowtime = DateTime.Now;
                    for (int i = 0; i < userlist.users.Count; i++)
                    {
                        if (principal.EmailAddress == userlist.users[i].useremail)
                        {
                            logontime = userlist.users[i].logontime;
                            TimeSpan time;
                            time = nowtime - logontime;
                            if (time.Days > 60) { return "2"; }
                            userlist.users[i].logontime = nowtime;
                            SaveUserList<Userlist>(userlist);
                            return "1";
                        }
                    }
                        
                }
            }

            return "0";
        }

        /// <summary>
        /// Read a user list config file
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name"></param>
        /// <param name="section"></param>
        /// <param name="user"></param>
        /// <returns></returns>
        
    public class Userlist
    {
        public List<user> users { get; set; }


    }

    public class user
    {
        public string useremail { get; set; }
        public DateTime logontime { get; set; }

    }

    public static T LoadUserList<T>() where T : new()
    {
        TextReader reader = null;
        try
        {
            var serializer = new XmlSerializer(typeof(T));
            reader = new StreamReader(DefaultRoot + '\\' + "userlist.xml");
            return (T)serializer.Deserialize(reader);
        }
        finally
        {
            if (reader != null)
                reader.Close();
        }
    }

    public static void SaveUserList<T>(T data)
    {
        TextWriter writer = null;
        try
        {
            var serializer = new XmlSerializer(typeof(T));
            writer = new StreamWriter(DefaultRoot + '\\' + "userlist.xml", false);
            serializer.Serialize(writer, data);
        }
        finally
        {
            if (writer != null)
                writer.Close();
        }
    }

    }

   


}

