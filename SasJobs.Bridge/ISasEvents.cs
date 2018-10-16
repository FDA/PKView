
namespace SasJobs.Bridge
{
    /// <summary>
    /// Provides a set of events for <see cref="SasJobs.Bridge.ISasBridge"/>
    /// </summary>
    public interface ISasEvents
    {       
        /// <summary>
        /// Handle SAS events from a particular language service
        /// </summary>
        /// <param name="languageService">a SAS language service</param>
        void hook(SAS.ILanguageService languageService);

        /// <summary>
        /// Detach events from the language service
        /// </summary>
        /// <param name="languageService">a SAS language service</param>
        void unhook(SAS.ILanguageService languageService);
    }
}
