package com.recallthat.App

import android.app.Application

class RecallThatApplication : Application() {
    lateinit var appEnvironment: AppEnvironment
        private set

    override fun onCreate() {
        super.onCreate()
        appEnvironment = AppEnvironment(this)
    }
}
