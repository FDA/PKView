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
    
    public partial class IPORTAL_EX_DATASET
    {
        public IPORTAL_EX_DATASET()
        {
            this.IPORTAL_EX_FILE = new HashSet<IPORTAL_EX_FILE>();
        }
    
        public int EX_DATASET_ID { get; set; }
        public int STUDY_ID { get; set; }
    
        public virtual IPORTAL_STUDY IPORTAL_STUDY { get; set; }
        public virtual ICollection<IPORTAL_EX_FILE> IPORTAL_EX_FILE { get; set; }
    }
}
