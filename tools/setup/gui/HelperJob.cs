using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
// Keep child transfers tied to the elevated helper even if it is terminated.
public static class SchoolbellHelperJob {
 [StructLayout(LayoutKind.Sequential)] struct Basic { public long ProcessTime,JobTime; public uint Flags; public UIntPtr Min,Max; public uint Active; public UIntPtr Affinity; public uint Priority,Scheduling; }
 [StructLayout(LayoutKind.Sequential)] struct Io { public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes; }
 [StructLayout(LayoutKind.Sequential)] struct Extended { public Basic Basic; public Io Io; public UIntPtr ProcessMemory,JobMemory,PeakProcess,PeakJob; }
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int info,ref Extended limits,uint size);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
 [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
 static IntPtr handle;
 public static void Attach() {
  handle=CreateJobObject(IntPtr.Zero,null);
  if(handle==IntPtr.Zero)throw new Win32Exception();
  var limits=new Extended();limits.Basic.Flags=0x2000; // KILL_ON_JOB_CLOSE
  if(!SetInformationJobObject(handle,9,ref limits,(uint)Marshal.SizeOf(typeof(Extended))) || !AssignProcessToJobObject(handle,GetCurrentProcess()))throw new Win32Exception();
  // Intentionally retained until OS closes handles at process exit. No inherited handle.
 }
}
