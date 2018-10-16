using System;
using System.Runtime.Serialization;
using System.Xml.Linq;

namespace SasJobs.Messages
{
    /// <summary>
    /// Represents the settings to run a SAS Job
    /// </summary>
    [DataContract]
    public class JobSettings
    {
        /// <summary>
        /// Gets or sets the SAS job Id
        /// </summary>
        [DataMember]
        public Guid Id { get; set; }

        /// <summary>
        /// Gets or sets the name of the SAS procedure to execute
        /// </summary>
        [DataMember]
        public string ProcedureName { get; private set; }

        /// <summary>
        /// Gets or sets the input data for the SAS procedure in xml string format
        /// </summary>
        [DataMember]
        public string XmlInputData { get; private set; }

        /// <summary>
        /// Gets or sets the xml map to correctly transfer the data to sas
        /// </summary>
        [DataMember]
        public string XmlMap { get; private set; }

        public JobSettings(JobRequest request) {
            this.ProcedureName = request.ProcedureName;
            // Normalize xml data to make sure it is in a format that can be written to the sas libname
            this.XmlInputData = XElement.Parse(request.XmlInputData).ToString(); 
            this.XmlMap = XElement.Parse(request.XmlMap).ToString();
        }
      
        /// <summary>
        /// Determine if two JobSettings are equal
        /// </summary>
        /// <param name="obj">Object to compare to</param>
        /// <returns>true if this is equal to obj</returns>
        public override bool Equals(object obj)
        {
            // return false if null
            if (obj == null) return false;

            // return false if cannot be cast
            JobSettings s = obj as JobSettings;
            if ((System.Object)s == null) return false;

            // return true if they match
            return ((this.ProcedureName ?? "").Equals(s.ProcedureName ?? "") 
                && (this.XmlInputData ?? "").Equals(s.XmlInputData ?? ""));
        }

        /// <summary>
        /// Get the Jobsettings hash code
        /// </summary>
        /// <returns>the hash code</returns>
        public override int GetHashCode()
        {
            return (ProcedureName + XmlInputData).ToLowerInvariant().GetHashCode();
        }
       
    }
}
