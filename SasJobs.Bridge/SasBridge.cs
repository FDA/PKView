using SASObjectManager;
using System;
using System.Data;
using System.Data.OleDb;
using System.IO;
using System.Text;
using System.Xml.Serialization;
using System.Globalization;
using SAS;
using System.Collections.Generic;





namespace SasJobs.Bridge
{
    /// <summary>
    /// Represents a bridge allowing execution of SAS stored procedures in a workspace
    /// </summary>
    public class SasBridge : ISasBridge
    {     
        /// <summary>
        /// Gets the SAS Jobs service base path
        /// </summary>
        public static string SasServicePath { 
            get {
                if (sasServicePath == null)
                {
                    var potentialRoot = new DirectoryInfo(AppDomain.CurrentDomain.BaseDirectory);                    
                    while (potentialRoot.GetDirectories("Stored Procedures").Length == 0)
                        potentialRoot = potentialRoot.Parent;
                    sasServicePath = potentialRoot.FullName;
                }
                return sasServicePath;
            }
        }

        /// </summary>
        /// <param name="filepath"></param>
        /// <returns></returns>
        static private DataTable ReadCsv(string filepath)
        {

            string csvfilename = Path.GetFileNameWithoutExtension(filepath);
            DataTable dt = new DataTable("NewTable");
            DataRow row;

            string[] lines = File.ReadAllLines(filepath, Encoding.UTF8);
            string[] head = lines[0].Split(',');
            int cnt = head.Length;
            for (int i = 0; i < cnt; i++)
            {
                dt.Columns.Add(head[i]);
            }
            for (int i = 0; i < lines.Length; i++)
            {
                lines[i].Trim();
                if ((string.IsNullOrWhiteSpace(lines[i])))
                {
                    continue;
                }
                try
                {
                    row = dt.NewRow();
                    row.ItemArray = GetRow(lines[i], cnt);
                    dt.Rows.Add(row);
                }
                catch { }
            }
            dt.TableName = csvfilename;
            dt.Rows[0].Delete();
            dt.AcceptChanges();
            return dt;
        }
        /// <summary>

        /// </summary>

        /// <returns></returns>
        static private string[] GetRow(string line, int cnt)
        {

            string[] strs = line.Split(',');
            if (strs.Length == cnt)
            {
                return RemoveQuotes(strs);
            }
            List<string> list = new List<string>();
            int n = 0, begin = 0;
            bool flag = false;

            for (int i = 0; i < strs.Length; i++)
            {

                if (strs[i].IndexOf("\"") == -1
                    || (flag == false && strs[i][0] != '\"'))
                {
                    list.Add(strs[i]);
                    continue;
                }

                n = 0;
                foreach (char ch in strs[i])
                {
                    if (ch == '\"')
                    {
                        n++;
                    }
                }
                if (n % 2 == 0)
                {
                    list.Add(strs[i]);
                    continue;
                }
                flag = true;
                begin = i;
                i++;
                for (i = begin + 1; i < strs.Length; i++)
                {
                    foreach (char ch in strs[i])
                    {
                        if (ch == '\"')
                        {
                            n++;
                        }
                    }
                    if (strs[i][strs[i].Length - 1] == '\"' && n % 2 == 0)
                    {
                        StringBuilder sb = new StringBuilder();
                        for (; begin <= i; begin++)
                        {
                            sb.Append(strs[begin]);
                            if (begin != i)
                            {
                                sb.Append(",");
                            }
                        }
                        list.Add(sb.ToString());
                        break;
                    }
                }
            }
            return RemoveQuotes(list.ToArray());
        }
        /// <summary>

        /// </summary>
        /// <param name="strs"></param>
        /// <returns></returns>
        static string[] RemoveQuotes(string[] strs)
        {
            for (int i = 0; i < strs.Length; i++)
            {

                if (strs[i] == "\"\"")
                {
                    strs[i] = "";
                    continue;
                }

                if (strs[i].Length > 2 && strs[i][0] == '\"' && strs[i][strs[i].Length - 1] == '\"')
                {
                    strs[i] = strs[i].Substring(1, strs[i].Length - 2);
                }

                strs[i] = strs[i].Replace("\"\"", "\"");
            }
            return strs;
        }

        //static DataTable GetDataTableFromCsv(string path, bool isFirstRowHeader)
        //{
        //    string header = isFirstRowHeader ? "Yes" : "No";

        //    string pathOnly = Path.GetDirectoryName(path);
        //    string fileName = Path.GetFileName(path);
        //    string csvfilename = Path.GetFileNameWithoutExtension(path);

        //    string sql = @"SELECT * FROM [" + fileName + "]";

        //    using (OleDbConnection connection = new OleDbConnection(
        //              @"Provider=Microsoft.Jet.OLEDB.4.0;Data Source=" + pathOnly +
        //              ";Extended Properties='Text;HDR=Yes;IMEX=1;FMT=Delimited(,)';"))
        //    using (OleDbCommand command = new OleDbCommand(sql, connection))
        //    using (OleDbDataAdapter adapter = new OleDbDataAdapter(command))
        //    {
        //        DataTable dataTable = new DataTable();
        //        dataTable.Locale = CultureInfo.CurrentCulture;
        //        adapter.Fill(dataTable);
        //        dataTable.TableName = csvfilename;
        //        //dataTable.Columns.Remove(dataTable.Columns["obs"]);
        //        return dataTable;
        //    }
        //}
        /// <summary>
        /// Load a data file
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="name"></param>
        /// <param name="section"></param>
        /// <param name="user"></param>
        /// <returns></returns>
        /// 
        public static String Load()
        {

            System.Data.DataSet dset = new System.Data.DataSet();


            string[] files = Directory.GetFiles(@"\\localhost\Output Files\PkView\Peter\", "*.csv", SearchOption.TopDirectoryOnly);
            if (files.Length > 0)
            {
                foreach (string file in files)
                {
                    DataTable dt = ReadCsv(file);
                    File.Delete(file);
                    dset.Tables.Add(dt);

                }
            }

            
            var writer = new System.IO.StringWriter();
            dset.WriteXml(writer, System.Data.XmlWriteMode.WriteSchema);
            return writer.ToString();
            

        }

        private static string sasServicePath = null;

        /// <summary>
        /// Gets or sets the SAS events
        /// </summary>
        public SasEvents Events { get; set; }
        
        /// <summary>
        /// Gets or sets the shared workspace pool
        /// </summary>
        private static ISasWsPool pool { get; set; }  

        /// <summary>
        /// Path to the stored process repository
        /// </summary>
        private string repositoryPath { get { return SasServicePath + "\\Stored Procedures"; } }

        /// <summary>
        /// Gets or sets the associated pooled workspace
        /// </summary>
        private IPooledObject pooledWorkspace { get; set; }

        /// <summary>
        /// Gets or sets the associated SAS workspace
        /// </summary>
        private SAS.IWorkspace workspace { get; set; }

        /// <summary>
        /// Gets or sets the SAS workspace's language service
        /// </summary>
        private SAS.ILanguageService languageService { get; set; }

        /// <summary>
        /// Name of the alternative sasWork dataset libname used to avoid file locking
        /// </summary>
        private string sasWork { get { return "user"; } }

        /// <summary>
        /// Creates the shared workspace pool for all SasBridge instances
        /// </summary>
        static SasBridge()
        {
            pool = new SasWsPool();
        }

        /// <summary>
        /// Creates a SAS bridge
        /// </summary>
        public SasBridge()
        {
            this.Events = new SasEvents();
        }

        /// <summary>
        /// Run a SAS stored procedure
        /// </summary>
        /// <param name="procedure">stored procedure name</param>
        /// <param name="xmlInputData">Input data encoded in xml format</param>
        /// <param name="xmlMap">SAS xml map that defines how sas will read the data</param>
        /// /// <returns>True in case of success, false if a workspace is 
        /// not available in the pool at this time</returns>     
        public bool RunProcedure(string procedure, string xmlInputData, string xmlMap)
        {
            this.pooledWorkspace = pool.GetWorkspace();

            // Return false if no workspace is available at this time
            if (this.pooledWorkspace == null) return false;

            this.workspace = this.pooledWorkspace.SASObject;
         
            this.languageService = this.workspace.LanguageService;

            // Ensure the language service is not busy
            this.languageService.Cancel();
            this.languageService.Reset();
            this.languageService.Continue();

            // Set asynchronous mode
            this.languageService.Async = true;

            // Tell the language service to suspend in case of sas error
            this.languageService.SuspendOnError = true;

            // Stored process repository
            this.languageService.StoredProcessService.Repository = "file:" + repositoryPath;

            // Hook events
            this.Events.hook(this.languageService);

            // Send the data to the SAS workspace; create the WEBSVC libname
            this.sendData(xmlInputData, xmlMap);

            // Execute the stored procedure
            this.languageService.StoredProcessService.Execute(procedure, 
                "SasSpPath=\"" + repositoryPath + "\"");

            return true;
        }

        /// <summary>
        /// Flush the SAS log
        /// </summary>
        /// <param name="log">log sink to use</param>
        /// <returns>Number of lines flushed</returns>
        public int FlushLog(ISasLog log)
        {
            Array carriage, lineTypes, lines;
            this.languageService.FlushLogLines(1000, out carriage, out lineTypes, out lines);
            for (int i = 0; i < lines.GetLength(0); i++)
            {
                var line = (lines.GetValue(i) as string).Trim();
                switch ((SAS.LanguageServiceLineType)lineTypes.GetValue(i))
                {
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeError:
                        log.Error(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeWarning:
                        log.Warning(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeFootnote:
                        log.Footnote(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeByline:
                        log.ByLine(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeHilighted:
                        log.Highlighted(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeMessage:
                        log.Message(line); break;                    
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeNote:
                        log.Note(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeSource:
                        log.Source(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeTitle:
                        log.Title(line); break;  
                     default:
                        log.Normal(line); break;
                }
            }
            return lines.GetLength(0);
        }

        /// <summary>
        /// Flush the sas output
        /// </summary>
        /// <param name="log">log sink to use</param>
        /// <returns>Number of lines flushed</returns>
        public int FlushList(ISasLog log)
        {
            Array carriage, lineTypes, lines;
            this.languageService.FlushListLines(1000, out carriage, out lineTypes, out lines);
            for (int i = 0; i < lines.GetLength(0); i++)
            {
                var line = (lines.GetValue(i) as string).Trim();
                switch ((SAS.LanguageServiceLineType)lineTypes.GetValue(i))
                {
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeError:
                        log.Error(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeWarning:
                        log.Warning(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeFootnote:
                        log.Footnote(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeByline:
                        log.ByLine(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeHilighted:
                        log.Highlighted(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeMessage:
                        log.Message(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeNote:
                        log.Note(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeSource:
                        log.Source(line); break;
                    case SAS.LanguageServiceLineType.LanguageServiceLineTypeTitle:
                        log.Title(line); break;
                    default:
                        log.Normal(line); break;
                }
            }
            return lines.GetLength(0);
        }

        /// <summary>
        /// Retrieve the SAS job results
        /// </summary>
        /// <returns>The job results in xml format</returns>
        /// 
        public string GetResult()
        {
            return SasBridge.Load();
        }
        //public string GetResult()
        //{
        //    // Try to copy data from the adapter into the DataSet
        //    var outputDataset = new System.Data.DataSet();
        //    var tmpDataset = new System.Data.DataSet();
        //    //var tmpDataset1 = new System.Data.DataSet();
        //    // Create data connection
        //    var connectionString = "provider=sas.IOMProvider.1;sas workspace ID=" + workspace.UniqueIdentifier;
        //    //var connectionString = "provider=sas.IOMProvider;sas workspace ID=" + "SAS Workspace";
        //    //this.workspace.Name = workspace.UniqueIdentifier;
        //    using (var dataConnection = new OleDbConnection(connectionString))
        //    {
        //        //ObjectKeeper keeper = new ObjectKeeper();
        //        //keeper.AddObject(1, "SASServer", this.workspace);
        //        dataConnection.Open();

        //        // Check if the dataset listing table exists in the schema
        //        var tableExists = dataConnection.GetSchema("Tables",
        //            new string[4] { null, null, sasWork + ".DATA", "TABLE" }).Rows.Count > 0;

        //        // If dataset listing was found retrieve tables
        //        if (tableExists)
        //        {
        //            // Create ole adapter
        //            using (var oleAdapter = new OleDbDataAdapter())
        //            {
        //                // Configure select query in ole adapter
        //                oleAdapter.SelectCommand =
        //                    new OleDbCommand("select * from " + sasWork + ".DATA", dataConnection);

        //                // Fill the list of tables
        //                oleAdapter.Fill(tmpDataset, "tables");

        //                // Retrieve all the data tables
        //                foreach (DataRow row in tmpDataset.Tables[0].Rows)
        //                {
        //                    string datasetName = (string)row["dataset"];

        //                    oleAdapter.SelectCommand =
        //                        new OleDbCommand("select * from " + sasWork + '.' + datasetName, dataConnection);
        //                    oleAdapter.Fill(outputDataset, datasetName.Replace(sasWork + '.', ""));
        //                }
        //            }
        //        }

        //        dataConnection.Close();
        //    }

        //    var writer = new System.IO.StringWriter();
        //    outputDataset.WriteXml(writer, System.Data.XmlWriteMode.WriteSchema);
        //    return writer.ToString();
        //}

//        public string GetResult()
//        {
//            // Try to copy data from the adapter into the DataSet
//            var outputDataset = new DataSet();
//            var tmpDataset = new DataSet();
//            var tmpDataset1 = new DataSet();
//            // Create data connection
//            var connectionString = "provider=sas.IOMProvider.1;sas workspace ID=" + workspace.UniqueIdentifier;
//            //var connectionString = "provider=sas.IOMProvider.1;sas workspace ID= *";
//             //Get the command line arguments
//            //String[] args = Environment.GetCommandLineArgs();
//            //// The first element will be the name of the running program
//            //// so there should be two arguments in the list.
//            //if (args.Length < 2)
//            //{
//            //    Console.WriteLine("Required arguments: <libname>.<tablename>.");
//            //    Environment.Exit(-1);
//            //}
//            //String itable = args[1];

//            OleDbConnection cn = new OleDbConnection();
//cn.ConnectionString = "Provider=sas.IOMProvider; Data Source=_LOCAL_";

//OleDbCommand cmd = cn.CreateCommand();
//cmd.CommandType = CommandType.TableDirect;
////cmd.CommandText = itable;
//    // Open the connection and print the version number.
//    cn.Open();
//    Console.WriteLine( "SAS Server Version: " + cn.ServerVersion );

//    // Execute the command and get an OleDbDataReader object.
//    OleDbDataReader reader = cmd.ExecuteReader();
//    DataTable schema = reader.GetSchemaTable();
//    Console.Write("Columns: ");
//    for (int i = 0; i < schema.Rows.Count; ++i)
//    {
//        if (i > 0) { Console.Write(", "); }
//        Console.Write(schema.Rows[i]["ColumnName"]);
//    }
//    Console.WriteLine();
//            //ObjectFactory factory = new ObjectFactory();
//            //ServerDef server = new ServerDef();
//            //SAS.Workspace ws = (SAS.Workspace)factory.CreateObjectByServer("ws", true, server, "", "");
//            //ObjectKeeper keeper = new ObjectKeeper();
//            //keeper.AddObject(1, "SASServer", workspace);
         
            
//            //ADODB.Connection adoConnection = new ADODB.Connection();
//            //ADODB.Recordset adoRecordset = new ADODB.Recordset();
//            //adoRecordset.ActiveConnection = adoConnection;

//            //adoConnection.Open("provider=sas.IOMProvider.1; Data Source=_LOCAL_;","","",0);
//            //Console.WriteLine("SAS Server Version: " +
//            //       adoConnection.Properties["DBMS Version"].Value);
//            //ADODB.Recordset adoRecordset = new ADODB.Recordset();
//            //adoRecordset.ActiveConnection = adoConnection;
//            //Console.Write("Columns: ");
//            //for (int i = 0; i < adoRecordset.Fields.Count; ++i)
//            //{
//            //    if (i > 0) { Console.Write(", "); }
//            //    Console.Write(adoRecordset.Fields[i].Name);
//            //}
            
//    //        adoRecordset.Open(itable, Missing.Value, ADODB.CursorTypeEnum.adOpenForwardOnly,
//    //ADODB.LockTypeEnum.adLockReadOnly, (int)ADODB.CommandTypeEnum.adCmdTableDirect);
//            //Console.WriteLine("SAS" +adoConnection.Properties[0].Value);


//            using (var dataConnection = new OleDbConnection(connectionString))
//            {
//                dataConnection.Open();
//                // Configure select query in ole adapter

//                var oleAdapter1 = new OleDbDataAdapter();
//                oleAdapter1.SelectCommand =
//                    new OleDbCommand("select * from " + sasWork + ".DATA", dataConnection);

//                // Fill the list of tables
//                oleAdapter1.Fill(tmpDataset1, "tables");



//                // Check if the dataset listing table exists in the schema
//                var tableExists = dataConnection.GetSchema("Tables",
//                    new string[4] { null, null, sasWork + ".DATA", "TABLE" }).Rows.Count > 0;

//                // If dataset listing was found retrieve tables
//                if (tableExists)
//                {
//                    // Create ole adapter
//                    using (var oleAdapter = new OleDbDataAdapter())
//                    {
//                        // Configure select query in ole adapter
//                        oleAdapter.SelectCommand =
//                            new OleDbCommand("select * from " + sasWork + ".DATA", dataConnection);

//                        // Fill the list of tables
//                        oleAdapter.Fill(tmpDataset, "tables");

//                        // Retrieve all the data tables
//                        foreach (DataRow row in tmpDataset.Tables[0].Rows)
//                        {
//                            string datasetName = (string)row["dataset"];

//                            oleAdapter.SelectCommand =
//                                new OleDbCommand("select * from " + sasWork + '.' + datasetName, dataConnection);
//                            oleAdapter.Fill(outputDataset, datasetName.Replace(sasWork + '.', ""));
//                        }
//                    }
//                }

//                dataConnection.Close();
//            }

//            var writer = new System.IO.StringWriter();
//            outputDataset.WriteXml(writer, System.Data.XmlWriteMode.WriteSchema);
//            return writer.ToString();
//        }

        /// <summary>
        /// Release the workspace back to the pool
        /// </summary>
        public void Release()
        {
            this.Events.unhook(this.languageService);
            this.languageService.Cancel();
            this.languageService.Reset();
            this.languageService = null;
            this.workspace.Close();
            this.workspace = null;
            this.pooledWorkspace.ReturnToPool();
            this.pooledWorkspace = null;
        }

        /// <summary>
        /// This method sends the given dataset to the Workspace, and
        /// assigns the WEBSVC libref to that inputDataset
        /// </summary>
        /// <param name="xmlInputData">The input dataset</param>
        /// <param name="xmlMap">SAS xml map that defines how sas will read the data</param>
        private void sendData(String xmlInputData, String xmlMap)
        {
            string assignedName = "";
            
            // Create temporary filerefs for the xml data and xml map
            var xmlDataFileRef = this.workspace.FileService.AssignFileref("WEBSVC", "TEMP", "", "", out assignedName);
            //var xmlMapFileRef = this.workspace.FileService.AssignFileref("MAP", "TEMP", "", "", out assignedName);

            // Create a properly formatted input file for SAS
            var file = xmlDataFileRef.OpenTextStream(SAS.StreamOpenMode.StreamOpenModeForWriting, 20000);            
            file.Separator = System.Environment.NewLine;   
            file.Write("<?xml version=\"1.0\" standalone=\"yes\" ?>");
            //file.Write("<?xml version=\"1.0\" encoding=\"windows-1252\" ?>");
            file.Write(xmlInputData);           
            file.Close();

            // Create a properly formatted xml map for SAS
            //file = xmlMapFileRef.OpenTextStream(SAS.StreamOpenMode.StreamOpenModeForWriting, 20000);
            //file.Separator = System.Environment.NewLine;
            //file.Write("<?xml version=\"1.0\" standalone=\"yes\" ?>");
            //file.Write(xmlMap);
            //file.Close();

            // We instruct the sas dataservice to decode the input into wlatin1 so SAS can read it correctly
            //this.workspace.DataService.AssignLibref("WEBSVC", "XMLV2", "", "ENCODING=wlatin1 XMLMAP=MAP");
            //this.workspace.DataService.AssignLibref("WEBSVC", "XML", "", "ENCODING=wlatin1");
            this.workspace.DataService.AssignLibref("WEBSVC", "XML", "", "ENCODING=wlatin1");

        }
    }
}
