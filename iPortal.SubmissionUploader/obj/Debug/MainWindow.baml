   M S B A M L   `   `   `  ����  iPortal.SubmissionUploader+    %iPortal.SubmissionUploader.MainWindow   5   	   \ XPresentationFramework, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35R NWindowsBase, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35W SPresentationCore, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35D 9http://schemas.microsoft.com/winfx/2006/xaml/presentation    5   	   R NSystem.Xaml, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089:x,http://schemas.microsoft.com/winfx/2006/xaml     5   	   -   5          � Title$!  iPortal Submission Uploader��5   	    � Icon$ app.ico��6-   $	��350��5   	   $	��525��6    � 
ResizeMode$ CanMinimize=�6"    � 	Resources 5         VSP %� IsVirtualizing %� VirtualizationMode��%R   &	        �� 5   
   .R�5	      $�  . $ 	Recycling=�5      5      5      .��5      � -   5         �Name$ MainGrid��5       � RowDefinitions 5   
   �� 5      $
��Auto �6   �� 5      .+�5   
   � {�6   �� *NotUploading+ 5      �� 5      $
��Auto �6    �� 5      $
��Auto �6    �� 5      $
��Auto �6    �� 5      $
��Auto �6    �� 5      $
��Auto �6    �� 5      $
��147* �6     � ColumnDefinitions 5      �� 5      -   5        	 ��Name$	 FirstColumn��5   #   $
��Auto �68   �� 5      .+�5       �� $��Submission source:��6   $��
10,10,10,0q�61   �� 5!      -   5        
 ��Name$
 SubmissionRepository��5!      #��[  5"      $��1��63   $��	0,10,10,0q�6C   ��5!   5   �� *RepositoryList+ �� SelectedItem 6\   �� *SelectedRepository+5"   C   �� 5#      -   5         ��Name$ CustomUriLabel��5#      $��Path:��6,   $��1��6<   $��
10,10,10,0q�6�   y�6I   ��  �� ElementName$ CustomUriGrid�� �� Path$ 
Visibility�6�   � 5$      -   5        $ CustomUriGrid��5$      $��1��6*   $��1��67   $��0,0,0,0q�6�   y�6G   �� *SelectedRepository+ " SelectionToVisibilityConverter �� 	Converter# [  �� ConverterParameter$ Custom�� 5%      �� 5&      �� 5'      $
��Auto �6'   .+�53      ��  �� TextWrapping$
 Wrap=�6   $��	0,10,10,0q�6y   ��6.   �� *CustomRepositoryUri+ �� UpdateSourceTrigger$ PropertyChanged=�6y   �� 54      -   5        $��Browse��54      $��1��6*   $��	0,10,10,0q�6:   $��60��6M   $y�	Collapsed=�6y   55      �� 56      $��Submission to upload:��6   $��2��65   $��
10,10,10,0q�6B   y�6V   �� $ SubmissionsList��$ 
Visibility��� 57      -   5        $
 SubmissionsList��57       �� 
IsEditable . $��2��59   #   $��1��60   $��	0,10,10,0q�6@   ��57   0   �� *SubmissionFolderList+ 6]   �� *SelectedSubmissionFolder+ �� Delay$
 1000��y�58      �� *SubmissionFolderList+  NullToVisibilityConverter# [ 59   @   �� 5:      -	   5         ��Name$ 
PickSerial��5:      $��3��6+   $��
10,10,10,0q�68   y�6L   �� $ SerialsList��$ 
Visibility� d� 	IsChecked 5;      �� *UploadSingleSerialFolder+.��5<      �� $��Specific Serial Number:��6   5=      �� 5>      -
   5        $
 SerialsList��5>      $��1��5@   N   $��3��6^   $��	0,10,10,0q�6k   ��5>   ,   �� *SerialFolderList+ 6U   �� *SelectedSerialFolder+y�5?      �� *ShowSerialFolderList+  BoolToVisibilityConverter# [ {�5@      �� $ 
PickSerial��$ 	IsChecked�5A      �� 5B      $>��8No data was found for the currently selected submission.��6   $��2��5D      $��4��6%   $��
10,10,10,0q�62   
���  ��y�5C      �� *ShowSerialFoldersNotFound+# [ 5D   F   5E      � 5F   
   $��1��6    5G      �� 5H      �� 5I      $
��Auto �6#    5K      �� 5L      �� 5M      $
��Auto �6    �� 5N      $
��Auto �6    .+�5P      �� $��
10,10,10,0q�5Q      $��1��6&   $��2��63   y�5P      �� *ShowProgressBar+# [ ��6q   �� *TaskProgress.Message+5Q   3   � 5R      $��0q�5S      $��2��6%   $��10,10,10,10q�62   y�5R      �� *ShowProgressBar+# [  � Value 6w   �� *TaskProgress.Value+5S   2   �� 5T      -   5        $��Upload��5T      $��75��5V      $��1��6   $��2��6,   $��
0,10,10,10q�69   {�5T   &   �� $ SerialsList��$ 	IsVisible�y�5U      �� *	Uploading+ $  InverseBoolToVisibilityConverter# [ 5V   M   �� 5W      -   5        $��Cancel��5W      $��75��5Y      $��1��6   $��2��6,   $��
0,10,10,10q�69   y�5X      �� *	Uploading+# [ 5Y   M   5Z      5[      5\      