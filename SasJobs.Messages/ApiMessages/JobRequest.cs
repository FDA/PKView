using System;
using System.Data;
using System.Xml.Linq;

namespace SasJobs.Messages
{
    /// <summary>
    /// Represents a request to run a SAS Job
    /// </summary>
    public class JobRequest
    {
        /// <summary>
        /// Gets or sets the name of the SAS procedure to execute
        /// </summary>
        public string ProcedureName { get; set; }

        /// <summary>
        /// Gets or sets the input data for the SAS procedure in xml string format
        /// </summary>
        public string XmlInputData { get; set; }

        /// <summary>
        /// Gets or sets the xml map to correctly transfer the data to sas
        /// </summary>
        public string XmlMap { get; set; }

        /// <summary>
        /// Default constructor to allow the class to be serialized.
        /// </summary>
        public JobRequest() { }

        /// <summary>
        /// Class constructor. Create job settings from a procedure name and a data set
        /// </summary>
        /// <param name="procedureName">Name of the sas procedure</param>
        /// <param name="data">input data for the SAS procedure</param>
        public JobRequest(string procedureName, DataSet data)
        {
            this.ProcedureName = procedureName;
            this.XmlInputData = data.GetXml();
            this.XmlMap = this.buildXmlMap(data);
        }

        /// <summary>
        /// Build an xml map to use when transferring data to SAS from the provided data set
        /// </summary>
        /// <param name="data">data to map</param>
        /// <returns>the xml map in string format</returns>
        private string buildXmlMap(DataSet data)
        {
            var map = new XElement("SXLEMAP", new XAttribute("version", "2.1")); // Root element of the SAS XMLMAP v2.1 syntax

            // Add each table to the map
            foreach (DataTable table in data.Tables)
            {
                var tablePath = String.Format("/{0}/{1}", data.DataSetName, table.TableName);
                var mapTable = new XElement("TABLE", new XAttribute("name", table.TableName),
                    new XElement("TABLE-PATH", new XAttribute("syntax", "XPath"), tablePath));

                // Add each column in the table
                foreach (DataColumn column in table.Columns)
                {
                    var mapColumn = new XElement("COLUMN", new XAttribute("name", column.ColumnName));
                    mapColumn.Add(new XElement("PATH", new XAttribute("syntax", "XPath"),
                            String.Format("{0}/{1}", tablePath, column.ColumnName)));

                    // Add the data type
                    var sasXmlType = this.toSasType(column.DataType);
                    mapColumn.Add(new XElement("TYPE", sasXmlType[0]));
                    mapColumn.Add(new XElement("DATATYPE", sasXmlType[1]));

                    // If data type is string, add length, for now we will just set a safe value of 2000
                    if (sasXmlType[1] == "string") mapColumn.Add(new XElement("LENGTH", "2000"));

                    mapTable.Add(mapColumn);
                }
                map.Add(mapTable);
            }

            // Convert to string and return
            return map.ToString();
        }

        /// <summary>
        /// Converts from a dataset column data type to a sas XMLMAP type specification
        /// </summary>
        /// <param name="type"></param>
        /// <returns></returns>
        private string[] toSasType(Type type)
        {
            switch (type.Name)
            {
                case "Boolean": return new string[] { "numeric", "integer" };
                case "Byte": return new string[] { "numeric", "integer" };
                case "SByte": return new string[] { "numeric", "integer" };
                case "Decimal": return new string[] { "numeric", "integer" };
                case "Int16": return new string[] { "numeric", "integer" };
                case "Int32": return new string[] { "numeric", "integer" };
                case "Int64": return new string[] { "numeric", "integer" };
                case "UInt16": return new string[] { "numeric", "integer" };
                case "UInt32": return new string[] { "numeric", "integer" };
                case "UInt64": return new string[] { "numeric", "integer" };

                case "Double": return new string[] { "numeric", "double" };
                case "Single": return new string[] { "numeric", "double" };

                case "DateTime": return new string[] { "character", "datetime" };

                case "TimeSpan": return new string[] { "character", "string" };
                case "Guid": return new string[] { "character", "string" };
                case "Char": return new string[] { "character", "string" };
                default: return new string[] { "character", "string" };
            }
        }
    }
}
