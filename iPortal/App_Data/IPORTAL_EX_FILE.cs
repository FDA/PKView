//------------------------------------------------------------------------------
// <auto-generated>
//    This code was generated from a template.
//
//    Manual changes to this file may cause unexpected behavior in your application.
//    Manual changes to this file will be overwritten if the code is regenerated.
// </auto-generated>
//------------------------------------------------------------------------------

namespace iPortal.App_Data
{
    using System;
    using System.Collections.Generic;
    
    public partial class IPORTAL_EX_FILE
    {
        public int EX_FILE_ID { get; set; }
        public int FILE_ID { get; set; }
        public int EX_DATASET_ID { get; set; }
    
        public virtual IPORTAL_EX_DATASET IPORTAL_EX_DATASET { get; set; }
        public virtual IPORTAL_FILE IPORTAL_FILE { get; set; }
    }
}
