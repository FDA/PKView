using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace iPortal.SubmissionUploader.Converters
{
    /// <summary>
    /// Convert a combobox selection to a visibility value
    /// </summary>
    public sealed class SelectionToVisibilityConverter : IValueConverter
    {
        /// <summary>
        /// Convert from a combobox selection to a visibility value
        /// </summary>
        /// <param name="selectedItem">Item currently selected</param>
        /// <param name="targetType"></param>
        /// <param name="desiredItem">Item that will cause visibility.visible</param>
        /// <param name="culture"></param>
        /// <returns></returns>
        public object Convert(object selectedItem, Type targetType, object desiredItem, CultureInfo culture)
        {
            return Equals(selectedItem, desiredItem) ? Visibility.Visible : Visibility.Collapsed;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}
