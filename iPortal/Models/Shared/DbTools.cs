using System;
using System.Collections.Generic;
using System.Data.Entity;
using System.Data.Entity.Infrastructure;
using System.Linq;
using System.Web;

namespace iPortal.Models
{
    public static class DbTools
    {
        /// <summary>
        /// Save database changes checking for concurrency issues and solve those overwriting
        /// with the last entry submitted
        /// </summary>
        /// <param name="db">Database context to save</param>
        public static void SaveDbChangesConcurrentOverwrite(DbContext db)
        {
            bool saveFailed;
            do
            {
                saveFailed = false;
                try
                {
                    db.SaveChanges();
                }
                catch (DbUpdateConcurrencyException ex)
                {
                    saveFailed = true;

                    // Update original values from the database
                    foreach (var entry in ex.Entries)
                        entry.OriginalValues.SetValues(entry.GetDatabaseValues());
                }

            } while (saveFailed);
        }

        /// <summary>
        /// Save changes to the database unless there is a concurrency collision
        /// </summary>
        /// <param name="db">Database context to save</param>
        /// <returns>False if saving failed (a collision occured)</returns>
        public static bool SaveDbChangesConcurrentFail(DbContext db)
        {
            try { db.SaveChanges(); }
            catch (DbUpdateConcurrencyException) {                 
                return false; 
            }
            return true;
        }
    }
}