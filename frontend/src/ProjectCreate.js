import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { showSuccessToast, showErrorToast } from './ProjectTostify';


const ProjectCreate = () => {
    const url = `${process.env.REACT_APP_BACKEND_URL}`
    const [project, setProject] = useState({ name: '', description: '' });
    const navigate = useNavigate();

    const handleCreate = async (e) => {
        e.preventDefault();

        try {
            await axios.post(`${url}/projects`, project);
            showSuccessToast(`Project was created. Project name: ${project.name}, Project description: ${project.description}`);

            navigate('/projects');
        } catch (error) {
            showErrorToast(`Project was not created. Error: ${error}`);
            console.error('Error creating project:', error);
        }
    };

    return (
        <div>
            <h1>Creating new Project</h1>
            <form onSubmit={handleCreate}>
                <div>
                    <label htmlFor="name">Name:</label>
                    <input
                        type="text"
                        id="name"
                        name="name"
                        value={project.name}
                        onChange={(e) => setProject({ ...project, name: e.target.value })}
                    />
                </div>
                <div>
                    <label htmlFor="description">Description:</label>
                    <textarea
                        id="description"
                        name="description"
                        value={project.description}
                        onChange={(e) => setProject({ ...project, description: e.target.value })}
                    />
                </div>
                <button type="submit">Create</button>
            </form>
        </div>
    );
};

export default ProjectCreate;