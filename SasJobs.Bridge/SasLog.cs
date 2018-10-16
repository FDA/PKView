using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SasJobs.Bridge
{
    public abstract class SasLog: ISasLog
    {
        /// <summary>
        /// Log a message using the default logging method
        /// </summary>
        /// <param name="message">The message</param>
        abstract public void Default(string message);

        /// <summary>
        /// Log a normal message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Normal(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a warning message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Warning(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log an error message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Error(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a footnote
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Footnote(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a byline message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void ByLine(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a highlighted message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Highlighted(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Message(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a note
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Note(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a title
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Title(string message)
        {
            Default(message);
        }

        /// <summary>
        /// Log a source code message
        /// </summary>
        /// <param name="message">The message</param>
        public virtual void Source(string message)
        {
            Default(message);
        }
    }
}
