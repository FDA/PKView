
namespace SasJobs.Bridge
{
    /// <summary>
    /// Allows logging SAS code execution
    /// </summary>
    public interface ISasLog
    {
        /// <summary>
        /// Log a normal message
        /// </summary>
        /// <param name="message">The message</param>
        void Normal(string message);

        /// <summary>
        /// Log a warning message
        /// </summary>
        /// <param name="message">The message</param>
        void Warning(string message);

        /// <summary>
        /// Log an error message
        /// </summary>
        /// <param name="message">The message</param>
        void Error(string message);

        /// <summary>
        /// Log a footnote
        /// </summary>
        /// <param name="message">The message</param>
        void Footnote(string message);

        /// <summary>
        /// Log a byline message
        /// </summary>
        /// <param name="message">The message</param>
        void ByLine(string message);

        /// <summary>
        /// Log a highlighted message
        /// </summary>
        /// <param name="message">The message</param>
        void Highlighted(string message);

        /// <summary>
        /// Log a message
        /// </summary>
        /// <param name="message">The message</param>
        void Message(string message);

        /// <summary>
        /// Log a note
        /// </summary>
        /// <param name="message">The message</param>
        void Note(string message);

        /// <summary>
        /// Log a title
        /// </summary>
        /// <param name="message">The message</param>
        void Title(string message);

        /// <summary>
        /// Log a source code message
        /// </summary>
        /// <param name="message">The message</param>
        void Source(string message);
    }
}
