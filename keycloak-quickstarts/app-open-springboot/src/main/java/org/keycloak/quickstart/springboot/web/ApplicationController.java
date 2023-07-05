/*
 * JBoss, Home of Professional Open Source
 *
 * Copyright 2017 Red Hat, Inc. and/or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */
package org.keycloak.quickstart.springboot.web;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

@Controller
public class ApplicationController {

    @Autowired
    private HttpServletRequest request;

    @RequestMapping(value = "/protected", method = RequestMethod.GET)
    public String handleProtected(Model model) {
        return "protected";
    }

    @RequestMapping(value = "/protected/premium", method = RequestMethod.GET)
    public String handlePremium(Model model) {
        return "premium";
    }

    @RequestMapping(value = "/logout", method = RequestMethod.GET)
    public String handleLogoutt() throws ServletException {
        request.logout();
        return "redirect:/";
    }

    @RequestMapping(value = "/", method = RequestMethod.GET)
    public String handleHome(Model model) throws ServletException {
        return "home";
    }

    @RequestMapping(value = "/accessDenied", method = RequestMethod.GET)
    public String handleAccessDenied() throws ServletException {
        return "access-denied";
    }
}