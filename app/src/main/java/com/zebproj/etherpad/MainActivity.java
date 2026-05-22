/*
 EtherPad is a multi-touch synthesizer, using the Csound Android SDK for sound
 generation.

 EtherPad heavily borrows code from the MultiTouchXY example, found in
 the collection of Csound Android Examples provided in the Csound source code.

 The Csound Examples were created by Steven Yi and Victor Lazzarini in 2011.

 Copyright (C) 2014 Paul Batchelor

 This file is part of EtherPad.

 EtherPad is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program. If not, see <http://www.gnu.org/licenses/>.
*/
package com.zebproj.etherpad;

import android.app.ActionBar;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.view.LayoutInflater;
import android.view.Menu;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.View.OnTouchListener;
import android.widget.PopupMenu;
import android.widget.PopupMenu.OnMenuItemClickListener;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

import csnd.CsoundCallbackWrapper;
import csnd.CsoundOboe;

public class MainActivity extends Activity implements OnMenuItemClickListener {

    private static final String TAG = "EtherPad";

    static {
        // Csound's native engine — JNI loader picks the right ABI from jniLibs.
        // Load order matters: dependencies before dependents.
        System.loadLibrary("c++_shared");
        System.loadLibrary("sndfile");
        System.loadLibrary("oboe");
        System.loadLibrary("csoundandroid");
    }

    private CsoundOboe csound;
    private CsoundCallbackWrapper csoundMessages;
    public MultiTouchView multiTouchView;

    private final int[] touchIds = new int[10];
    private final float[] touchX = new float[10];
    private final float[] touchY = new float[10];

    private final int[] sizes = { R.id.size_4, R.id.size_5, R.id.size_6, R.id.size_7, R.id.size_8,
            R.id.size_9, R.id.size_10, R.id.size_11, R.id.size_12, R.id.size_13, R.id.size_14 };

    private final int[] keys = { R.id.key_C, R.id.key_Cs, R.id.key_D, R.id.key_Ds, R.id.key_E,
            R.id.key_F, R.id.key_Fs, R.id.key_G, R.id.key_Gs, R.id.key_A,
            R.id.key_As, R.id.key_B };

    private final int[] octaves = {
            R.id.octave_two,
            R.id.octave_one,
            R.id.octave_zero,
            R.id.octave_neg_one,
            R.id.octave_neg_two
    };

    private final int[] sounds = {
            R.id.sound_1,
            R.id.sound_2,
            R.id.sound_3
    };

    private final int[] scaleMajor   = { 0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23 };
    private final int[] scaleMinor   = { 0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19, 20, 23 };
    private final int[] scalePent    = { 0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 30 };
    private final int[] scaleBlues   = { 0, 3, 5, 6, 7, 10, 12, 15, 17, 18, 19, 22, 24, 27 };
    private final int[] scaleChrom   = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 };
    private final int[] scaleWhole   = { 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26 };
    private final int[] scaleOct     = { 0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 16, 18, 19, 21 };
    private final int[] scaleFlam    = { 0, 1, 4, 5, 7, 8, 11, 12, 13, 16, 17, 19, 21, 22 };
    private final int[] scaleDefault = { 0, 2, 4, 7, 9, 11, 12, 14, 16, 19, 21, 24, 26, 28 };
    private final int[] scaleBP      = { -1 };

    private int getTouchIdAssignment() {
        for (int i = 0; i < touchIds.length; i++) {
            if (touchIds[i] == -1) return i;
        }
        return -1;
    }

    private int getTouchId(int touchId) {
        for (int i = 0; i < touchIds.length; i++) {
            if (touchIds[i] == touchId) return i;
        }
        return -1;
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        ActionBar actionBar = getActionBar();
        if (actionBar != null) {
            actionBar.setDisplayShowTitleEnabled(false);
            actionBar.setDisplayShowHomeEnabled(false);
            actionBar.setDisplayUseLogoEnabled(false);
            actionBar.setDisplayShowCustomEnabled(true);
            LayoutInflater inflater = (LayoutInflater) getSystemService(Context.LAYOUT_INFLATER_SERVICE);
            actionBar.setCustomView(inflater.inflate(R.layout.actionbar, null));
        }

        for (int i = 0; i < touchIds.length; i++) {
            touchIds[i] = -1;
            touchX[i] = -1;
            touchY[i] = -1;
        }

        multiTouchView = new MultiTouchView(this, null);
        multiTouchView.setOnTouchListener(new OnTouchListener() {
            @Override
            public boolean onTouch(View v, MotionEvent event) {
                multiTouchView.onTouchEvent(event);
                final int action = event.getAction() & MotionEvent.ACTION_MASK;
                switch (action) {
                    case MotionEvent.ACTION_DOWN:
                    case MotionEvent.ACTION_POINTER_DOWN:
                        for (int i = 0; i < event.getPointerCount(); i++) {
                            int pointerId = event.getPointerId(i);
                            int id = getTouchId(pointerId);
                            if (id == -1) {
                                id = getTouchIdAssignment();
                                if (id != -1) {
                                    touchIds[id] = pointerId;
                                    touchX[id] = event.getX(i) / multiTouchView.getWidth();
                                    touchY[id] = 1 - (event.getY(i) / multiTouchView.getHeight());
                                    if (csound != null) {
                                        csound.SetControlChannel(String.format("touch.%d.x", id), touchX[id]);
                                        csound.SetControlChannel(String.format("touch.%d.y", id), touchY[id]);
                                        csound.InputMessage(String.format("i1.%d 0 -2 %d", id, id));
                                    }
                                }
                            }
                        }
                        break;

                    case MotionEvent.ACTION_MOVE:
                        for (int i = 0; i < event.getPointerCount(); i++) {
                            int pointerId = event.getPointerId(i);
                            int id = getTouchId(pointerId);
                            if (id != -1) {
                                touchX[id] = event.getX(i) / multiTouchView.getWidth();
                                touchY[id] = 1 - (event.getY(i) / multiTouchView.getHeight());
                                if (csound != null) {
                                    csound.SetControlChannel(String.format("touch.%d.x", id), touchX[id]);
                                    csound.SetControlChannel(String.format("touch.%d.y", id), touchY[id]);
                                }
                            }
                        }
                        break;

                    case MotionEvent.ACTION_POINTER_UP:
                    case MotionEvent.ACTION_UP: {
                        int activePointerIndex = event.getActionIndex();
                        int pointerId = event.getPointerId(activePointerIndex);
                        int id = getTouchId(pointerId);
                        if (id != -1) {
                            touchIds[id] = -1;
                            if (csound != null) {
                                csound.InputMessage(String.format("i-1.%d 0 0 %d", id, id));
                            }
                        }
                        break;
                    }
                }
                return true;
            }
        });

        setContentView(multiTouchView);
        startCsound();
    }

    private void startCsound() {
        try {
            String csd = getResourceFileAsString(R.raw.etherpad);
            csound = new CsoundOboe();

            // Route Csound's stdout/stderr into logcat so .csd compile errors are visible.
            csoundMessages = new CsoundCallbackWrapper(csound.getCsound()) {
                @Override
                public void MessageCallback(int attr, String msg) {
                    Log.d(TAG, "csound: " + msg.trim());
                }
            };
            csoundMessages.SetMessageCallback();
            csound.SetMessageLevel(7); // 1=note amps, 2=out-of-range, 4=warnings

            int compileResult = csound.CompileCsdText(csd);
            Log.d(TAG, "CompileCsdText returned " + compileResult);
            if (compileResult != 0) {
                Log.e(TAG, "Csound failed to compile the .csd; result=" + compileResult);
                return;
            }

            int startResult = csound.Start();
            Log.d(TAG, "Start returned " + startResult);
            if (startResult != 0) {
                Log.e(TAG, "Csound failed to start; result=" + startResult);
                return;
            }

            // Play() spins up the Oboe audio thread; from here, samples flow.
            csound.Play();
            Log.d(TAG, "Csound is now playing");

            multiTouchView.numberOfNotesProvider = () -> {
                if (csound == null) return 8.0;
                return csound.GetControlChannel("size");
            };
        } catch (Throwable t) {
            Log.e(TAG, "Failed to start Csound", t);
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (csound != null) {
            try {
                csound.Stop();
                csound.Cleanup();
            } catch (Throwable ignored) {
            }
            csound = null;
        }
    }

    private String getResourceFileAsString(int resId) {
        StringBuilder str = new StringBuilder();
        InputStream is = getResources().openRawResource(resId);
        try (BufferedReader r = new BufferedReader(new InputStreamReader(is))) {
            String line;
            while ((line = r.readLine()) != null) {
                str.append(line).append("\n");
            }
        } catch (IOException ignored) {
        }
        return str.toString();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        menu.clear();
        MenuInflater inflater = getMenuInflater();
        inflater.inflate(R.menu.main, menu);
        return true;
    }

    public void openSize(View view)   { openMenu("sizes"); }
    public void openKey(View view)    { openMenu("keys"); }
    public void openOctave(View view) { openMenu("octaves"); }
    public void openSound(View view)  { openMenu("sounds"); }
    public void openScale(View view)  { openMenu("scales"); }

    private void openMenu(String name) {
        Log.d(TAG, "openMenu " + name);
        int id = getResources().getIdentifier(name, "id", getPackageName());
        int menuId = getResources().getIdentifier(name, "menu", getPackageName());
        View myView = findViewById(id);
        if (myView == null) {
            myView = findViewById(R.id.wayleft);
        }
        PopupMenu popup = new PopupMenu(this, myView);
        popup.setOnMenuItemClickListener(this);
        MenuInflater inflater = popup.getMenuInflater();
        inflater.inflate(menuId, popup.getMenu());
        popup.show();
    }

    private void setSize(int size) {
        if (csound != null) csound.InputMessage(String.format("i100 0 0.5 %d", size));
        multiTouchView.invalidate();
    }

    private void setKey(int key) {
        if (csound != null) csound.InputMessage(String.format("i101 0 0.5 %d", key));
        multiTouchView.invalidate();
    }

    private void setOctave(int oct) {
        if (csound != null) csound.InputMessage(String.format("i102 0 0.5 %d", oct));
        multiTouchView.invalidate();
    }

    private void setSound(int sound) {
        if (csound != null) csound.InputMessage(String.format("i104 0 0.5 %d", sound));
        multiTouchView.invalidate();
    }

    private void setScale(int[] scale) {
        if (csound == null) return;
        if (scale[0] == -1) {
            csound.InputMessage("i103 0 0.5 -1");
        } else {
            csound.InputMessage(String.format(
                    "i103 0 0.5 %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
                    scale[0], scale[1], scale[2], scale[3],
                    scale[4], scale[5], scale[6], scale[7],
                    scale[8], scale[9], scale[10], scale[11],
                    scale[12], scale[13]));
        }
        multiTouchView.invalidate();
    }

    public void openAbout(View view) {
        Intent intent = new Intent(this, AboutActivity.class);
        startActivity(intent);
    }

    @Override
    public boolean onMenuItemClick(MenuItem item) {
        int id = item.getItemId();
        for (int i = 0; i < sizes.length; i++) {
            if (id == sizes[i]) { setSize(i + 4); return true; }
        }
        for (int i = 0; i < keys.length; i++) {
            if (id == keys[i]) { setKey(i); return true; }
        }
        for (int i = 0; i < octaves.length; i++) {
            if (id == octaves[i]) { setOctave(6 - i); return true; }
        }
        for (int i = 0; i < sounds.length; i++) {
            if (id == sounds[i]) { setSound(i); return true; }
        }

        if (id == R.id.scale_def)   { setScale(scaleDefault); return true; }
        if (id == R.id.scale_maj)   { setScale(scaleMajor); return true; }
        if (id == R.id.scale_min)   { setScale(scaleMinor); return true; }
        if (id == R.id.scale_pent)  { setScale(scalePent); return true; }
        if (id == R.id.scale_flam)  { setScale(scaleFlam); return true; }
        if (id == R.id.scale_blues) { setScale(scaleBlues); return true; }
        if (id == R.id.scale_chrom) { setScale(scaleChrom); return true; }
        if (id == R.id.scale_whole) { setScale(scaleWhole); return true; }
        if (id == R.id.scale_oct)   { setScale(scaleOct); return true; }
        if (id == R.id.scale_bp)    { setScale(scaleBP); return true; }
        return false;
    }
}
