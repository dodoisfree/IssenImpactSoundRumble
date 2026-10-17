using System;
using System.Runtime.InteropServices;
public static class ImpactSDL {
    public static void ScaleWav(string source,string target,double gain) {
        byte[] data=System.IO.File.ReadAllBytes(source);
        if (gain<0 || gain>1) throw new ArgumentOutOfRangeException("gain");
        int offset=12; bool found=false;
        while(offset+8<=data.Length) {
            string kind=System.Text.Encoding.ASCII.GetString(data,offset,4);
            int size=BitConverter.ToInt32(data,offset+4);
            if(size<0 || (long)offset+8+size>data.Length) throw new System.IO.InvalidDataException("Invalid WAV chunk");
            if(kind=="fmt " && (size<16 || BitConverter.ToInt16(data,offset+8)!=1 || BitConverter.ToInt16(data,offset+22)!=16))
                throw new System.IO.InvalidDataException("Expected 16-bit PCM WAV");
            if(kind=="data") {
                for(int i=offset+8;i+1<offset+8+size;i+=2) {
                    short value=(short)Math.Round(BitConverter.ToInt16(data,i)*gain);
                    byte[] sample=BitConverter.GetBytes(value);data[i]=sample[0];data[i+1]=sample[1];
                }
                found=true;break;
            }
            offset+=8+size+(size%2);
        }
        if(!found) throw new System.IO.InvalidDataException("Missing WAV data");
        System.IO.File.WriteAllBytes(target,data);
    }
    [DllImport("kernel32", CharSet=CharSet.Unicode)] public static extern IntPtr LoadLibrary(string path);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool SDL_SetHint(string name,string value);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool SDL_Init(uint flags);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SDL_GetJoysticks(out int count);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SDL_OpenJoystick(uint id);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern ushort SDL_GetJoystickVendor(IntPtr joy);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern ushort SDL_GetJoystickProduct(IntPtr joy);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SDL_GetJoystickName(IntPtr joy);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern void SDL_UpdateJoysticks();
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool SDL_JoystickConnected(IntPtr joy);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] [return:MarshalAs(UnmanagedType.I1)] public static extern bool SDL_RumbleJoystick(IntPtr joy,ushort low,ushort high,uint ms);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern void SDL_CloseJoystick(IntPtr joy);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern void SDL_free(IntPtr data);
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern void SDL_Quit();
    [DllImport("SDL3", CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SDL_GetError();
    public static void MakeSound(string path) {
        int hz=44100, count=(int)(hz*0.24); var rand=new Random(412);
        using(var file=new System.IO.BinaryWriter(System.IO.File.Create(path))) {
            file.Write(System.Text.Encoding.ASCII.GetBytes("RIFF")); file.Write(36+count*2);
            file.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt ")); file.Write(16);
            file.Write((short)1);file.Write((short)1);file.Write(hz);file.Write(hz*2);
            file.Write((short)2);file.Write((short)16);
            file.Write(System.Text.Encoding.ASCII.GetBytes("data"));file.Write(count*2);
            for(int i=0;i<count;i++) {
                double t=(double)i/hz;
                double attack=Math.Min(1,t/0.0015);
                double metal=(Math.Sin(2*Math.PI*1733*t)+0.6*Math.Sin(2*Math.PI*2861*t)+0.35*Math.Sin(2*Math.PI*4217*t))/1.95;
                double noise=(rand.NextDouble()*2-1)*Math.Exp(-t/0.009);
                double bass=Math.Sin(2*Math.PI*105*t)*Math.Exp(-t/0.025);
                double value=attack*(0.19*metal*Math.Exp(-t/0.045)+0.16*noise+0.16*bass);
                file.Write((short)(Math.Max(-1,Math.Min(1,value))*32767));
            }
        }
    }
}
